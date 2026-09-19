-- =============================================================================
-- ⚡ ULTRA INSTINCT V24.8.2 PERF (SYNTAX FIX + NEW MODES)
-- =============================================================================
local shared = odh_shared_plugins
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

local VERSION = "24.8.2 PERF"
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

local State = {
 Enabled=false, Target=nil, TargetScore=-1e9, TargetLockTime=0, LastCheck=0,
 LastApplied={H=-999,V=-999,Sim=-999,Int=-999,X=-999,Y=-999,Z=-999},
 MyRoot=nil, MyChar=nil, SmoothPos=nil, SmoothVel=nil,
 PingHistory={}, PingSmooth=60, CurrentMode="MIXED",
 MurdererPlayer=nil,
 Settings={leadMultiplier=1,verticalCorrection=1,reactionTime=DEFAULT_REACTION,minDistance=3,maxDistance=350,
   useGravity=true,useDrag=true,predictJump=true,targetLock=true,lockTime=2,prioritySystem=true,
   adaptiveLead=true,adaptiveGain=ADAPTIVE_GAIN,maxAdaptiveOffset=MAX_ADAPT},
 Stats={Shots=0,Hits=0,Kills=0,Deaths=0,StartTime=time(),BestStreak=0,CurrentStreak=0},
 ErrorHistory={}, AdaptiveOffset={x=0,y=0,z=0}, AdaptiveConfidence=.5,
 ThreatMap={}, WeaponType="knife", LastShotTime=0, LastShotTarget=nil, ShotArmed=false,
 LastJumpY=0, JumpCooldown=0,
}
local HitMarker = {}

local function IsMiniAvatar(p)
 if not p or not p.Character then return false end
 local c = p.Character
 local hum = c:FindFirstChildOfClass("Humanoid")
 if hum then
  if hum.HipHeight < 1.2 then return true end
  local depthScale = c:FindFirstChild("BodyDepthScale")
  local heightScale = c:FindFirstChild("BodyHeightScale")
  if (depthScale and depthScale.Value < 0.75) or (heightScale and heightScale.Value < 0.75) then
   return true
  end
 end
 return false
end

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
   for _,t in ipairs(types) do if n:find(t) then return true end end end end return false end
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

local function AdaptiveCorrection(err)
 if not State.Settings.adaptiveLead then return end
 local e=V3(abs(err.X)<DEAD_ZONE and 0 or err.X, abs(err.Y)<DEAD_ZONE and 0 or err.Y, abs(err.Z)<DEAD_ZONE and 0 or err.Z)
 local h=State.ErrorHistory; tinsert(h,e); if #h>30 then table.remove(h,1) end
 if #h>=10 then
  local avg=V3(0,0,0); for _,x in ipairs(h) do avg=avg+x end; avg=avg/#h
  local var=0; for _,x in ipairs(h) do var=var+(x-avg).Magnitude end; var=var/#h
  State.AdaptiveConfidence=State.AdaptiveConfidence*.8+clamp(1-var*.12,.2,1)*.2
  local g=State.Settings.adaptiveGain*State.AdaptiveConfidence; local m=State.Settings.maxAdaptiveOffset
  State.AdaptiveOffset.x=clamp(State.AdaptiveOffset.x+avg.X*g,-m,m)
  State.AdaptiveOffset.y=clamp(State.AdaptiveOffset.y+avg.Y*g,-m,m)
  State.AdaptiveOffset.z=clamp(State.AdaptiveOffset.z+avg.Z*g,-m,m)
  State.ErrorHistory={}
 end
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

local function RegisterHit()
 local s=State.Stats; s.Hits=s.Hits+1; s.Kills=s.Kills+1; s.CurrentStreak=s.CurrentStreak+1
 if s.CurrentStreak>s.BestStreak then s.BestStreak=s.CurrentStreak end
 State.ShotArmed=false; if HitMarker.Fire then HitMarker.Fire() end
end

local function ArmShot(t) State.LastShotTime=clock(); State.LastShotTarget=t; State.ShotArmed=true end

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
 lb.Text='<font color="#788296">Dealdough</font>'; lb.TextColor3=Color3.fromRGB(220,230,240); lb.TextSize=11; lb.ZIndex=11
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
  HUD.label.Text='<font color="#788296">Dealdough</font>'
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

-- ====== MENU SETUP (UPDATED OVERDRIVE H PLUGIN API) ======
local tab = (shared and shared.CreateTab) and shared.CreateTab("Ultra Instinct", "rbxassetid://6031280882") or nil
local section = (tab and tab.AddSection) and tab:AddSection("⚡ ULTRA INSTINCT " .. VERSION, "PERFORMANCE MODE") 
    or (shared and shared.AddSection and shared.AddSection("⚡ ULTRA INSTINCT "..VERSION)) or nil

if not section then
  section = {
    AddToggle = function() return function() end end,
    AddDropdown = function() return function() end end,
    AddButton = function() return function() end end,
  }
end

section:AddToggle("⚡ АКТИВИРОВАТЬ", function(st)
 State.Enabled=st
 if st then InitBase(); UpdateCache(); State.Target=nil else State.Target=nil end
end)
section:AddDropdown("Режим", {"PRO","INSTINCT","SECRETIVE","ANNIHILATING","ADAPTIVE","MIXED","PING100","PING200","PING300_400"}, function(s) State.CurrentMode=s; lastHUDKey=nil end)

local g = section:AddToggle("Gravity", function(s) State.Settings.useGravity=s end); pcall(function() g(true) end)
local d = section:AddToggle("Drags", function(s) State.Settings.useDrag=s end); pcall(function() d(tr
