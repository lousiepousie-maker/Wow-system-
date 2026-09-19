-- =============================================================================
-- ⚡ ULTRA INSTINCT V24.8.2 PERF (NATIVE OVERDRIVE H PLUGIN EDITION)
-- =============================================================================
local shared = odh_shared_plugins
if not shared or type(shared.CreateTab) ~= "function" then
    warn("[Ultra Instinct] Please execute this script through the Overdrive H plugin system.")
    return
end

local RUNTIME_KEY = "BetterODH_UltraInstinct_2026"
if type(_G[RUNTIME_KEY]) == "table" then
    if type(shared.Notify) == "function" then
        pcall(shared.Notify, "Ultra Instinct is already loaded.", 3)
    end
    return
end

local runtime = { version = "24.8.2 PERF" }
_G[RUNTIME_KEY] = runtime

local function notify(text, seconds)
    if type(shared.Notify) == "function" then 
        pcall(shared.Notify, text, seconds or 4) 
    end
end

-- Durable preferences system
local preferences = (function()
    local P = {file="UltraInstinct_settings.json", data={version=1, controls={}}, status="Not saved"}
    local env={}
    if type(getgenv)=="function" then
        local ok,result=pcall(getgenv)
        if ok and type(result)=="table" then env=result end
    end
    local read=type(readfile)=="function" and readfile or env.readfile
    local write=type(writefile)=="function" and writefile or env.writefile
    local exists=type(isfile)=="function" and isfile or env.isfile
    local okHttp,http=pcall(function() return game:GetService("HttpService") end)
    P.available=type(read)=="function" and type(write)=="function" and okHttp and http~=nil
    
    function P.Get(section,key)
        local group=P.data.controls[section]
        if type(group)=="table" then return group[key] end
    end
    function P.Save()
        if not P.available then return false end
        local ok,err=pcall(function() write(P.file,http:JSONEncode(P.data)) end)
        return ok
    end
    function P.Set(section,key,value)
        if typeof(value)=="Color3" then value={color3={value.R,value.G,value.B}} end
        if type(P.data.controls[section])~="table" then P.data.controls[section]={} end
        P.data.controls[section][key]=value
        return P.Save()
    end
    if P.available then
        local found=true
        if type(exists)=="function" then
            local ok,result=pcall(exists,P.file)
            if ok then found=result end
        end
        if found then
            local ok,text=pcall(read,P.file)
            if ok then
                local decoded,data=pcall(function() return http:JSONDecode(text) end)
                if decoded and type(data)=="table" and data.version==1 and type(data.controls)=="table" then
                    P.data=data
                end
            end
        end
    end
    return P
end)()
runtime.preferences = preferences

-- =============================================================================
-- ULTRA INSTINCT CORE LOGIC
-- =============================================================================
local internal_shared = odh_internal_shared
local gpl_preset = internal_shared and internal_shared.MM2_GPL or nil

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui      = game:GetService("CoreGui")
local LocalPlayer  = Players.LocalPlayer

local clamp,abs,floor,exp = math.clamp,math.abs,math.floor,math.exp
local clock,time = os.clock,os.time
local tinsert = table.insert
local V3 = Vector3.new

local VERSION = runtime.version
local GRAVITY, BULLET_SPEED = 196.2, 10000
local DEFAULT_REACTION, ADAPTIVE_GAIN, MAX_ADAPT = 0, 0.05, 8.0
local MAX_THREAT, HYSTERESIS, HIT_WINDOW, DEAD_ZONE = 500, 15, 0.6, 0.2
local MURDERER_SCAN = 0.001

if type(_G.__UI_CLEANUP) == "function" then pcall(_G.__UI_CLEANUP) end
local _conns = {}
local function track(c) _conns[#_conns+1] = c; return c end

local MODES = {
 PRO          = {h_base=90,h_ping=.25,h_speed=0.01,v_base=175,v_ping=.16,v_dist=.16,sim_base=72,sim_speed=.35,int_base=65,int_speed=-.25,offX=-8,offY=-102,offZ=0,desc="Pro Shot"},
 INSTINCT     = {h_base=90,h_ping=.32,h_speed=0.02,v_base=184,v_ping=.20,v_dist=.24,sim_base=50,sim_speed=.55,int_base=74,int_speed=-.15,offX=-9,offY=-51,offZ=-1,noMissed=true,antiSpam=true,desc="No Missed + Anti-Spam"},
 SECRETIVE    = {h_base=90,h_ping=.15,h_speed=0.02,v_base=105,v_ping=.10,v_dist=.12,sim_base=28,sim_speed=.2,int_base=60,int_speed=-.4,offX=12,offY=-78,offZ=-1},
 ANNIHILATING = {h_base=185,h_ping=.50,h_speed=0.02,v_base=175,v_ping=.30,v_dist=.35,sim_base=65,sim_speed=1.,int_base=20,int_speed=-.1,offX=-15,offY=-82,offZ=-1},
 ADAPTIVE     = {h_base=125,h_ping=.22,h_speed=0.02,v_base=125,v_ping=.14,v_dist=.18,sim_base=35,sim_speed=.4,int_base=50,int_speed=-.3,offX=-12,offY=-99,offZ=0,auto_switch=true},
 MIXED        = {h_base=120,h_ping=.28,h_speed=0.02,v_base=120,v_ping=.18,v_dist=.22,sim_base=45,sim_speed=.55,int_base=68,int_speed=-.18,offX=-12,offY=-95,offZ=-1,auto_switch=true,antiMini=true,antiSpam=true,noMissed=true,bodyShot=true,desc="Anti-Mini + Body Shot"},
 PING100      = {h_base=90,h_ping=.48,h_speed=0.03,v_base=179,v_ping=.35,v_dist=.28,sim_base=73,sim_speed=.60,int_base=64,int_speed=-.15,offX=-6,offY=-26,offZ=0,noMissed=true,antiSpam=true,bodyShot=true,desc="Optimized for 100+ ms Ping"},
 PING200      = {h_base=90,h_ping=.65,h_speed=0.04,v_base=170,v_ping=.50,v_dist=.35,sim_base=66,sim_speed=.70,int_base=59,int_speed=-.10,offX=-6,offY=-57,offZ=0,noMissed=true,antiSpam=true,bodyShot=true,desc="Optimized for 200+ ms Ping"},
 PING300_400  = {h_base=90,h_ping=.92,h_speed=0.05,v_base=177,v_ping=.72,v_dist=.45,sim_base=70,sim_speed=.85,int_base=72,int_speed=-.05,offX=-10,offY=-67,offZ=0,noMissed=true,antiSpam=true,bodyShot=true,desc="Ultra Compensation for 300-400 ms Ping"},
}

local ASUB = {
 CLOSE={h_base=90,h_ping=.30,h_speed=0.2,v_base=115,v_ping=.20,v_dist=.24,sim_base=40,sim_speed=.55,int_base=138,int_speed=-5,offX=-5,offY=-68,offZ=-2},
 MID  ={h_base=91,h_ping=.24,h_speed=0.0,v_base=150,v_ping=.16,v_dist=.20,sim_base=58,sim_speed=.45,int_base=85,int_speed=-3.5,offX=-11,offY=-148,offZ=-1},
 SNIP ={h_base=90, h_ping=.12,h_speed=0.2, v_base=190, v_ping=.10,v_dist=.12,sim_base=56,sim_speed=.18,int_base=125,int_speed=-4.5,offX=-7,offY=-90,offZ=-1},
 DEF  ={h_base=91,h_ping=.17,h_speed=0.2,v_base=172,v_ping=.12,v_dist=.14,sim_base=68,sim_speed=.25,int_base=57,int_speed=-3.8,offX=-6,offY=-45,offZ=0},
 HIGH_PING_MID={h_base=155,h_ping=.75,h_speed=0.03,v_base=115,v_ping=.58,v_dist=.38,sim_base=35,sim_speed=.75,int_base=90,int_speed=-.10,offX=30,offY=-89,offZ=0,noMissed=true,antiSpam=true,bodyShot=true},
}

local savedMode = preferences.Get("General", "Mode") or "MIXED"

local State = {
 Enabled=false, Target=nil, ForceTarget=nil, TargetScore=-1e9, TargetLockTime=0, LastCheck=0,
 LastApplied={H=-999,V=-999,Sim=-999,Int=-999,X=-999,Y=-999,Z=-999},
 MyRoot=nil, MyChar=nil, SmoothPos=nil, SmoothVel=nil,
 PingHistory={}, PingSmooth=60, CurrentMode=savedMode,
 MurdererPlayer=nil,
 Settings={
   leadMultiplier=preferences.Get("Toggles", "LeadMult") or 1,
   verticalCorrection=preferences.Get("Toggles", "VertCorr") or 1,
   reactionTime=DEFAULT_REACTION,minDistance=3,maxDistance=350,
   useGravity=preferences.Get("Toggles", "Gravity") ~= false,
   useDrag=preferences.Get("Toggles", "Drag") ~= false,
   predictJump=preferences.Get("Toggles", "PredictJump") ~= false,
   targetLock=preferences.Get("Toggles", "TargetLock") ~= false,
   adaptiveLead=preferences.Get("Toggles", "AdaptiveLead") ~= false,
   lockTime=preferences.Get("Toggles", "LockTime") or 2,
   prioritySystem=true,adaptiveGain=ADAPTIVE_GAIN,maxAdaptiveOffset=MAX_ADAPT
 },
 Stats={Shots=0,Hits=0,Kills=0,Deaths=0,StartTime=time(),BestStreak=0,CurrentStreak=0},
 ErrorHistory={}, AdaptiveOffset={x=0,y=0,z=0}, AdaptiveConfidence=.5,
 ThreatMap={}, WeaponType="knife", LastShotTime=0, LastShotTarget=nil, ShotArmed=false,
 LastJumpY=0, JumpCooldown=0,
}
local HitMarker = {}

local function GetRoot(p) local c=p and p.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function UpdateCache()
 local c=LocalPlayer.Character
 if c then
  State.MyChar=c; State.MyRoot=c:FindFirstChild("HumanoidRootPart"); State.WeaponType="knife"
  for _,it in ipairs(c:GetChildren()) do if it:IsA("Tool") then
   local n=it.Name:lower()
   if n:find("gun") or n:find("pistol") or n:find("revolver") then State.WeaponType="gun"
   elseif n:find("knife") or n:find("blade") then State.WeaponType="knife" end
   break
  end end
 else State.MyChar,State.MyRoot=nil,nil end
end

local function HasWeapon(p,types)
 if not p or not p.Character then return false end
 types=types or {"knife","blade","dagger","sword","gun","pistol","revolver"}
 local function ck(c) if not c then return false end
  for _,it in ipairs(c:GetChildren()) do if it:IsA("Tool") then local n=it.Name:lower()
   for _,t in ipairs(types) do if n:find(t) then return true end end end return false end
 return ck(p.Character) or ck(p:FindFirstChild("Backpack"))
end

local function IsMurderer(p)
 if not p then return false end
 if p:GetAttribute("Murderer")==true or p:GetAttribute("isMurderer")==true then return true end
 if HasWeapon(p,{"knife","blade","dagger","sword"}) then return true end
 local c=p.Character; return c and (c:FindFirstChild("Knife") or c:FindFirstChild("Blade")) or false
end

local function IsSheriff(p)
 if not p then return false end
 if p:GetAttribute("Sheriff")==true or p:GetAttribute("isSheriff")==true then return true end
 return HasWeapon(p,{"gun","pistol","revolver"}) and not IsMurderer(p)
end

local function SmoothPing(r) 
 local h=State.PingHistory; tinsert(h,r); if #h>15 then table.remove(h,1) end
 local s=0; for _,v in ipairs(h) do s=s+v end; State.PingSmooth=s/#h; return State.PingSmooth 
end

local function UpdateMurdererCache()
 local found=nil
 for _,pl in ipairs(Players:GetPlayers()) do
  if pl~=LocalPlayer and IsMurderer(pl) then found=pl; break end
 end
 State.MurdererPlayer=found
end

local function DetectSpamJump(sv)
 if not sv then return false end
 local currentY = sv.Y
 local timeSinceLastJump = clock() - State.JumpCooldown
 if currentY > 15 and timeSinceLastJump > 0.15 then
  State.LastJumpY = currentY
  State.JumpCooldown = clock()
  return true
 end
 return currentY > 8 and (clock() - State.JumpCooldown) < 0.5
end

local function DecayAdaptive()
 local o=State.AdaptiveOffset; o.x,o.y,o.z=o.x*.9,o.y*.9,o.z*.9
 if abs(o.x)<.01 then o.x=0 end; if abs(o.y)<.01 then o.y=0 end; if abs(o.z)<.01 then o.z=0 end
end

local function BuildThreatMap()
 local my=State.MyRoot; if not my then return end; local mp=my.Position; State.ThreatMap={}
 for _,pl in ipairs(Players:GetPlayers()) do if pl~=LocalPlayer then local r=GetRoot(pl)
  if r then local pos=r.Position; local d=(pos-mp).Magnitude; if d>MAX_THREAT then d=MAX_THREAT end
   local sp=r.AssemblyLinearVelocity.Magnitude; local t=0
   if IsMurderer(pl) then t=t+100 elseif IsSheriff(pl) then t=t+30 end
   t=t+(1/(d+1))*50+sp*2
   if r.CFrame.LookVector:Dot((mp-pos).Unit)>.5 then t=t+20 end
   local hum=pl.Character and pl.Character:FindFirstChild("Humanoid")
   if hum and hum.Health<30 then t=t*1.3 end
   State.ThreatMap[pl]=t
  end end end
end

local function resetSmooth() State.SmoothPos,State.SmoothVel=nil,nil end

local function FindBestTarget()
 if State.ForceTarget and State.ForceTarget.Parent == Players and State.ForceTarget.Character then
  local hum = State.ForceTarget.Character:FindFirstChild("Humanoid")
  if hum and hum.Health > 0 then return State.ForceTarget end
 end
 local now=clock()
 if State.Settings.targetLock and State.Target and State.Target.Parent==Players then
  local c=State.Target.Character
  if c and c:FindFirstChild("Humanoid") and c.Humanoid.Health>0 and (now-State.TargetLockTime<State.Settings.lockTime) then
   if IsMurderer(State.Target) then return State.Target end end end
 if now-State.LastCheck<0.02 then return State.Target end; State.LastCheck=now; BuildThreatMap()
 if not State.MyRoot then return nil end
 local cur=State.ThreatMap[State.Target] or -1e9; if State.Target and IsMurderer(State.Target) then cur=cur*0.01 end
 local best,bs=nil,-1e9
 for pl,th in pairs(State.ThreatMap) do if pl~=LocalPlayer then local s=IsMurderer(pl) and th*0.01 or th
  if s>bs then bs=s; best=pl end end end
 if State.Target and best and best~=State.Target and bs<cur+HYSTERESIS then return State.Target end
 if best~=State.Target then resetSmooth() end
 State.Target=best; State.TargetScore=bs; if best then State.TargetLockTime=now end; return best
end

local function SmoothData(root,dt)
 local p,vel=root.Position,root.AssemblyLinearVelocity
 if not State.SmoothPos then State.SmoothPos,State.SmoothVel=p,vel
 else State.SmoothPos=State.SmoothPos:Lerp(p,1-exp(-dt/0.06)); State.SmoothVel=State.SmoothVel:Lerp(vel,1-exp(-dt/0.01)) end
 return State.SmoothPos,State.SmoothVel
end

local function CalculateLead(sp,sv,mp,ping,dist)
 local bt=dist/(State.WeaponType=="gun" and 3000 or BULLET_SPEED); local tt=bt+ping/1000+State.Settings.reactionTime
 local v=sv; if State.Settings.useDrag then v=v*(0.98^(tt*10)) end
 local pp=sp+v*tt; if State.Settings.useGravity then pp=pp+V3(0,-0.5*GRAVITY*tt*tt,0) end; return pp-sp
end

local function ApplyGPL(sim,interval,x,y,z,h,v)
 if not gpl_preset then return end; local L=State.LastApplied
 if L.H==h and L.V==v and L.Sim==sim and L.Int==interval and L.X==x and L.Y==y and L.Z==z then return end
 L.H,L.V,L.Sim,L.Int,L.X,L.Y,L.Z=h,v,sim,interval,x,y,z
 pcall(function() if gpl_preset[4]  then gpl_preset[4](sim)      end end)
 pcall(function() if gpl_preset[5]  then gpl_preset[5](interval) end end)
 pcall(function() if gpl_preset[6]  then gpl_preset[6](x)        end end)
 pcall(function() if gpl_preset[7]  then gpl_preset[7](y)        end end)
 pcall(function() if gpl_preset[8]  then gpl_preset[8](z)        end end)
 pcall(function() if gpl_preset[9]  then gpl_preset[9](h)        end end)
 pcall(function() if gpl_preset[10] then gpl_preset[10](v)       end end)
end

local function InitBase()
 if not gpl_preset then return end
 pcall(function() if not internal_shared["RevertSettings_PrioritizeYourPing"] and gpl_preset[1] then gpl_preset[1]() end end)
 pcall(function() if not internal_shared["RevertSettings_PredictJump"]         and gpl_preset[2] then gpl_preset[2]() end end)
 pcall(function() if not internal_shared["RevertSettings_PredictLag"]          and gpl_preset[3] then gpl_preset[3]() end end)
end

local statsParagraph = nil

local function RegisterHit()
 local s=State.Stats; s.Hits=s.Hits+1; s.Kills=s.Kills+1; s.CurrentStreak=s.CurrentStreak+1
 if s.CurrentStreak>s.BestStreak then s.BestStreak=s.CurrentStreak end
 State.ShotArmed=false; if HitMarker.Fire then HitMarker.Fire() end
 if statsParagraph then
  local ac = s.Shots > 0 and string.format("%.1f%%", (s.Hits / s.Shots) * 100) or "-"
  statsParagraph:SetValue(string.format("Shots: %d | Hits: %d | Acc: %s | Kills: %d | Streak: %d", s.Shots, s.Hits, ac, s.Kills, s.CurrentStreak))
 end
end

local function ArmShot(t) 
 State.LastShotTime=clock(); State.LastShotTarget=t; State.ShotArmed=true 
 if statsParagraph then
  local s = State.Stats
  local ac = s.Shots > 0 and string.format("%.1f%%", (s.Hits / s.Shots) * 100) or "-"
  statsParagraph:SetValue(string.format("Shots: %d | Hits: %d | Acc: %s | Kills: %d | Streak: %d", s.Shots, s.Hits, ac, s.Kills, s.CurrentStreak))
 end
end

local function CheckHitProxy()
 if not State.ShotArmed then return end
 local t=State.LastShotTarget
 if not t or not t.Parent then State.ShotArmed=false; return end
 local c=t.Character; local h=c and c:FindFirstChildOfClass("Humanoid")
 if (not c) or (not h) or h.Health<=0 then RegisterHit() elseif clock()-State.LastShotTime>HIT_WINDOW then State.ShotArmed=false end
end

-- ====== HUD INITIALIZATION ======
local HUD={gui=nil,label=nil,stroke=nil,dot=nil,acc=0,hmH=nil,hmV=nil,hm=nil}
local lastHUDKey=nil
local function GetHUDGui()
 local parent; pcall(function() if gethui then parent=gethui() end end)
 pcall(function() if (not parent or typeof(parent)~="Instance") and getcore then parent=getcore() end end)
 if typeof(parent)~="Instance" then parent=CoreGui end
 local sg=parent:FindFirstChild("@ui_hud_v248")
 if not sg then sg=Instance.new("ScreenGui"); sg.Name="@ui_hud_v248"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true
  pcall(function() sg.ScreenInsets=Enum.ScreenInsets.None end)
  if syn and syn.protect_gui then pcall(syn.protect_gui,sg) end; sg.Parent=parent end
 return sg
end

local function dcol(d) if d<25 then return "#ff5a5a" elseif d<80 then return "#ffb454" else return "#9fb0c0" end end

local function startPulse()
 if not HUD.dot or not HUD.dot.Parent then return end
 local t1=TweenService:Create(HUD.dot,TweenInfo.new(.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Size=UDim2.new(0,11,0,11)})
 t1.Completed:Connect(function(st)
  if st==Enum.PlaybackState.Cancelled then return end
  if not HUD.dot or not HUD.dot.Parent then return end
  local t2=TweenService:Create(HUD.dot,TweenInfo.new(.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Size=UDim2.new(0,7,0,7)})
  t2.Completed:Connect(function(st2) if st2~=Enum.PlaybackState.Cancelled then startPulse() end end)
  t2:Play()
 end)
 t1:Play()
end

local function HUD_Init()
 local sg=GetHUDGui()
 local f=Instance.new("Frame"); f.Name="@uihud"; f.Size=UDim2.new(0,0,0,22); f.AutomaticSize=Enum.AutomaticSize.X
 f.Position=UDim2.new(.5,0,0,36); f.AnchorPoint=Vector2.new(.5,0)
 f.BackgroundColor3=Color3.fromRGB(12,14,18); f.BackgroundTransparency=.12; f.BorderSizePixel=0; f.ZIndex=10; f.Parent=sg
 Instance.new("UICorner",f).CornerRadius=UDim.new(1,0)
 local st=Instance.new("UIStroke",f); st.Color=Color3.fromRGB(70,80,100); st.Thickness=1; st.Transparency=.55
 local li=Instance.new("UIListLayout",f); li.FillDirection=Enum.FillDirection.Horizontal
 li.VerticalAlignment=Enum.VerticalAlignment.Center; li.SortOrder=Enum.SortOrder.LayoutOrder; li.Padding=UDim.new(0,6)
 local pd=Instance.new("UIPadding",f); pd.PaddingLeft=UDim.new(0,9); pd.PaddingRight=UDim.new(0,10)
 pd.PaddingTop=UDim.new(0,4); pd.PaddingBottom=UDim.new(0,4)
 local dot=Instance.new("Frame"); dot.LayoutOrder=1; dot.Size=UDim2.new(0,7,0,7)
 dot.BackgroundColor3=Color3.fromRGB(120,130,150); dot.BorderSizePixel=0; dot.ZIndex=11; dot.Parent=f
 Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
 local lb=Instance.new("TextLabel",f); lb.LayoutOrder=2; lb.Size=UDim2.new(0,0,1,0); lb.AutomaticSize=Enum.AutomaticSize.X
 lb.BackgroundTransparency=1; lb.Font=Enum.Font.GothamBold; lb.RichText=true
 lb.Text='<font color="#788296">Overdrive H</font>'; lb.TextColor3=Color3.fromRGB(220,230,240); lb.TextSize=11; lb.ZIndex=11
 local hm=Instance.new("Frame"); hm.Name="@hitmarker"; hm.Size=UDim2.new(0,40,0,40)
 hm.Position=UDim2.new(.5,0,.5,0); hm.AnchorPoint=Vector2.new(.5,.5); hm.BackgroundTransparency=1; hm.ZIndex=12; hm.Parent=sg
 local hmH=Instance.new("Frame",hm); hmH.Size=UDim2.new(0,24,0,2); hmH.Position=UDim2.new(.5,0,.5,0); hmH.AnchorPoint=Vector2.new(.5,.5)
 hmH.BackgroundColor3=Color3.fromRGB(255,255,255); hmH.BackgroundTransparency=1; hmH.BorderSizePixel=0; Instance.new("UICorner",hmH).CornerRadius=UDim.new(1,0)
 local hmV=Instance.new("Frame",hm); hmV.Size=UDim2.new(0,2,0,24); hmV.Position=UDim2.new(.5,0,.5,0); hmV.AnchorPoint=Vector2.new(.5,.5)
 hmV.BackgroundColor3=Color3.fromRGB(255,255,255); hmV.BackgroundTransparency=1; hmV.BorderSizePixel=0; Instance.new("UICorner",hmV).CornerRadius=UDim.new(1,0)
 HUD.gui,HUD.label,HUD.stroke,HUD.dot,HUD.hm,HUD.hmH,HUD.hmV=sg,lb,st,dot,hm,hmH,hmV
 startPulse()
end

HitMarker.Fire=function()
 if not HUD.hmH then return end
 HUD.hmH.BackgroundTransparency,HUD.hmV.BackgroundTransparency=0,0
 HUD.hmH.BackgroundColor3,HUD.hmV.BackgroundColor3=Color3.fromRGB(255,90,90),Color3.fromRGB(255,90,90)
 HUD.hm.Size=UDim2.new(0,28,0,28)
 TweenService:Create(HUD.hm,TweenInfo.new(.12,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.new(0,44,0,44)}):Play()
 TweenService:Create(HUD.hmH,TweenInfo.new(.26),{BackgroundTransparency=1}):Play()
 TweenService:Create(HUD.hmV,TweenInfo.new(.26),{BackgroundTransparency=1}):Play()
end

local function HUD_Update(dt)
 if not HUD.label then return end; HUD.acc=HUD.acc+dt; if HUD.acc<0.12 then return end; HUD.acc=0
 local m=State.MurdererPlayer
 local d5="-"; local hasD=false
 if m and State.MyRoot then local r=GetRoot(m)
  if r then d5=floor((r.Position-State.MyRoot.Position).Magnitude/5); hasD=true end end
 local key=(State.Enabled and 1 or 0) .. "|" .. State.CurrentMode .. "|" .. (m and m.Name or "-") .. "|" .. d5
 if key==lastHUDKey then return end
 lastHUDKey=key
 if not State.Enabled then
  HUD.label.Text='<font color="#788296">Overdrive H</font>'
  HUD.dot.BackgroundColor3=Color3.fromRGB(120,130,150)
  HUD.stroke.Color=Color3.fromRGB(70,80,100); HUD.stroke.Transparency=.55; return
 end
 local mt='<font color="#7ec8ff">⚡'..State.CurrentMode..'</font>'
 if m then
  local dtxt=hasD and (' <font color="'..dcol(d5*5)..'">'..(d5*5)..'</font>') or ""
  HUD.label.Text=mt..' <font color="#ff6e6e">▸'..m.Name..'</font>'..dtxt
  HUD.dot.BackgroundColor3=Color3.fromRGB(255,90,90)
  HUD.stroke.Color=Color3.fromRGB(255,80,80); HUD.stroke.Transparency=.15
 else
  HUD.label.Text=mt..' <font color="#788296">▸—</font>'
  HUD.dot.BackgroundColor3=Color3.fromRGB(120,180,255)
  HUD.stroke.Color=Color3.fromRGB(120,180,255); HUD.stroke.Transparency=.25
 end
end

-- =============================================================================
-- OVERDRIVE H PLUGIN UI INTEGRATION
-- =============================================================================
local pluginTab = shared.CreateTab(
    "Ultra Instinct", 
    "/dogwiener24/Logo/refs/heads/main/png-clipart-white-light-light-desktop-luminous-efficacy-halo-green-fresh-flame-effect-element-white-effect.png"
)

-- SECTION 1: MAIN CONTROLS
local mainSec = pluginTab:AddSection("⚡ Main Controls", "CORE PREDICTION ENGINE")

local engineToggleClosure = mainSec:AddToggle("⚡ Activate Engine", function(state)
    State.Enabled = state
    if state then 
        InitBase()
        UpdateCache()
        State.Target = nil 
        notify("Ultra Instinct Engine: ACTIVATED", 2)
    else 
        State.Target = nil 
        notify("Ultra Instinct Engine: DEACTIVATED", 2)
    end
end)

mainSec:AddDropdown("Prediction Mode", {"PRO","INSTINCT","SECRETIVE","ANNIHILATING","ADAPTIVE","MIXED","PING100","PING200","PING300_400"}, function(selected)
    State.CurrentMode = selected
    lastHUDKey = nil
    preferences.Set("General", "Mode", selected)
    notify("Mode switched to: " .. selected, 2)
end)

mainSec:AddKeybind("Engine Keybind Toggle", "U", function()
    if engineToggleClosure then
        engineToggleClosure()
    end
end)

mainSec:AddPlayerDropdown("Force Target Lock", function(player)
    if player then
        State.ForceTarget = player
        notify("Target hard locked to: " .. player.Name, 3)
    else
        State.ForceTarget = nil
        notify("Cleared forced target lock.", 2)
    end
end)

-- SECTION 2: FINE TUNING & PREDICTION
local tuneSec = pluginTab:AddSection("🎯 Fine Tuning", "CALIBRATION & COMPENSATIONS")

tuneSec:AddSlider("Lead Multiplier", 0.5, 3.0, State.Settings.leadMultiplier, function(val)
    State.Settings.leadMultiplier = val
    preferences.Set("Toggles", "LeadMult", val)
end)

tuneSec:AddSlider("Vertical Correction", 0.5, 3.0, State.Settings.verticalCorrection, function(val)
    State.Settings.verticalCorrection = val
    preferences.Set("Toggles", "VertCorr", val)
end)

tuneSec:AddSlider("Lock Duration (s)", 1, 10, State.Settings.lockTime, function(val)
    State.Settings.lockTime = val
    preferences.Set("Toggles", "LockTime", val)
end)

tuneSec:AddToggle("Gravity Compensation", function(state)
    State.Settings.useGravity = state
    preferences.Set("Toggles", "Gravity", state)
end)

tuneSec:AddToggle("Drag Compensation", function(state)
    State.Settings.useDrag = state
    preferences.Set("Toggles", "Drag", state)
end)

tuneSec:AddToggle("Predict Jump", function(state)
    State.Settings.predictJump = state
    preferences.Set("Toggles", "PredictJump", state)
end)

tuneSec:AddToggle("Adaptive Lead", function(state)
    State.Settings.adaptiveLead = state
    preferences.Set("Toggles", "AdaptiveLead", state)
end)

tuneSec:AddToggle("Target Lock", function(state)
    State.Settings.targetLock = state
    preferences.Set("Toggles", "TargetLock", state)
end)

-- SECTION 3: USER & TELEMETRY
local infoSec = pluginTab:AddSection("📊 Telemetry & User Info", "DIAGNOSTICS & STATS")

local userInfoStr = string.format("User: %s | Executor: %s | Tier: %s",
    tostring(shared.discord_name or "Local User"),
    tostring(shared.executor or "Unknown"),
    shared.is_exclusive_user and "Exclusive" or (shared.is_premium_user and "Premium" or (shared.is_serverbooster_user and "Booster" or "Free"))
)
infoSec:AddLabel(userInfoStr)

statsParagraph = infoSec:AddParagraph("Session Statistics", "Shots: 0 | Hits: 0 | Acc: - | Kills: 0 | Streak: 0")

infoSec:AddButton("Print Diagnostic Logs (F9)", function()
    local s = State.Stats
    local ac = s.Shots > 0 and string.format("%.1f%%", (s.Hits / s.Shots) * 100) or "-"
    print("══ ULTRA INSTINCT TELEMETRY ══")
    print("Shots: " .. s.Shots .. " | Hits: " .. s.Hits .. " | Accuracy: " .. ac)
    print("Kills: " .. s.Kills .. " | Deaths: " .. s.Deaths .. " | Best Streak: " .. s.BestStreak)
    print("Mode: " .. (State.CurrentMode or "-") .. " | Smooth Ping: " .. floor(State.PingSmooth) .. "ms")
    notify("Diagnostics printed to F9 Console.", 2)
end)

-- ====== MAIN LOOP ======
local _lw=0; local _lastScan=0
local function tick(dt)
 if not State.MyRoot or not State.MyRoot.Parent then UpdateCache(); if not State.MyRoot then DecayAdaptive(); return end end
 CheckHitProxy()

 local rp=LocalPlayer:GetNetworkPing()*1000; if rp<=0 then rp=State.PingSmooth or 100 end; local ping=SmoothPing(rp)
 local mk=State.CurrentMode; local mode=MODES[mk] or MODES.ADAPTIVE

 if (mk=="ADAPTIVE" or mk=="MIXED") and mode.auto_switch then
  if ping >= 300 then mode = MODES.PING300_400
  elseif ping >= 180 then mode = MODES.PING200
  elseif ping >= 90 then mode = MODES.PING100
  else mode = ASUB.MID end
 end

 local target = FindBestTarget()
 if not target then DecayAdaptive(); return end
 local tr = GetRoot(target)
 if not tr then DecayAdaptive(); return end

 local sp, sv = SmoothData(tr, dt)
 local mp = State.MyRoot.Position
 local dist = (sp - mp).Magnitude
 if dist < State.Settings.minDistance or dist > State.Settings.maxDistance then return end

 local lead = CalculateLead(sp, sv, mp, ping, dist)
 local lx, ly, lz = lead.X, lead.Y, lead.Z
 local speed = sv.Magnitude
 local isSpamJumping = DetectSpamJump(sv)

 local lc = State.Settings.leadMultiplier
 local vc = State.Settings.verticalCorrection
 local ad = State.AdaptiveOffset

 local cur_offY = mode.offY
 local hL = clamp((mode.h_base + ping*mode.h_ping + speed*mode.h_speed)*lc + ad.x*3, 50, 500)
 local vL = clamp((mode.v_base + ping*mode.v_ping + dist*mode.v_dist + ly*2)*vc + ad.y*3, 80, 500)
 local yO = 0
 
 if isSpamJumping then
  vL = vL + 55
  yO = yO + 7
 elseif State.Settings.predictJump then 
  local vs = sv.Y
  if vs > 3 then vL = vL + 35; yO = yO + 3
  elseif vs < -8 then vL = vL - 25; yO = yO - 4 end 
 end
 
 if mode.noMissed then hL = hL * 1.05 end
 local bodyAdjust = (mode.bodyShot and 18) or 0
 vL = vL - bodyAdjust

 local sim = clamp(mode.sim_base + speed*mode.sim_speed + abs(lx)*.5 + abs(ad.x)*.2, 15, 150)
 local intv = clamp(mode.int_base + speed*mode.int_speed - abs(lx)*.3 - abs(ad.x)*.1, 5, 120)
 local oX = mode.offX + lx*.5 + ad.x
 local oY = cur_offY + ly*.5 + yO + ad.y
 local oZ = mode.offZ + lz*.5 + ad.z

 ApplyGPL(floor(sim), floor(intv), floor(oX), floor(oY), floor(oZ), floor(hL), floor(vL))
end

track(RunService.Heartbeat:Connect(function(dt)
 local now=clock()
 if now-_lastScan>=MURDERER_SCAN then _lastScan=now; UpdateMurdererCache() end
 HUD_Update(dt)
 if State.Enabled then
  local ok,err=pcall(tick,dt)
  if not ok then if now-_lw>5 then _lw=now; warn("[UltraInstinct] "..tostring(err)) end end
 end
end))

track(Players.PlayerRemoving:Connect(function(p)
 if State.Target==p then State.Target=nil; State.TargetLockTime=0 end
 if State.ForceTarget==p then State.ForceTarget=nil end
 if State.MurdererPlayer==p then State.MurdererPlayer=nil end
 State.ThreatMap[p]=nil
end))

track(LocalPlayer.CharacterAdded:Connect(function()
 UpdateCache(); State.Target=nil; State.TargetLockTime=0; State.LastCheck=0; resetSmooth(); lastHUDKey=nil
end))

local function hookChar(char)
 local hum=char:WaitForChild("Humanoid",5)
 if hum then track(hum.Died:Connect(function() State.Stats.Deaths=State.Stats.Deaths+1; State.Stats.CurrentStreak=0 end)) end
 local function hookTool(it) if it:IsA("Tool") then track(it.Activated:Connect(function()
  if State.Enabled and State.WeaponType=="gun" then State.Stats.Shots=State.Stats.Shots+1; ArmShot(State.Target) end
 end)) end end
 for _,it in ipairs(char:GetChildren()) do hookTool(it) end
 track(char.ChildAdded:Connect(hookTool))
end
track(LocalPlayer.CharacterAdded:Connect(hookChar))
pcall(function() if LocalPlayer.Character then hookChar(LocalPlayer.Character) end end)

local function cleanup()
 State.Enabled=false; for _,c in ipairs(_conns) do pcall(function() c:Disconnect() end) end; _conns={}
 pcall(function() if HUD.gui then HUD.gui:Destroy() end end)
 HUD.gui,HUD.label,HUD.stroke,HUD.dot,HUD.hm,HUD.hmH,HUD.hmV=nil,nil,nil,nil,nil,nil,nil
 lastHUDKey=nil
 if _G.__UI_CLEANUP==cleanup then _G.__UI_CLEANUP=nil end
end
_G.__UI_CLEANUP=cleanup

UpdateCache(); UpdateMurdererCache(); HUD_Init()
notify("Ultra Instinct V24.8.2 ODH Plugin Loaded Successfully!", 4)
