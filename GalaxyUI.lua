-- Galaxy Milky Way UI addon for Overdrive H
-- Cosmetic/read-only UI only. Milky Way image attribution:
-- https://github.com/ruvkr/milkyway (CC BY-SA 4.0)

local shared = odh_shared_plugins
if type(shared) ~= "table" or type(shared.CreateTab) ~= "function" then
    warn("[Galaxy UI] Overdrive H addon API was not found.")
    return
end

local RUNTIME_KEY = "BetterODH_GalaxyUI_2026"
if _G[RUNTIME_KEY] then
    if type(shared.Notify) == "function" then
        pcall(shared.Notify, "Galaxy UI is already loaded.", 3)
    end
    return
end

local runtime = {
    version = "1.0.0",
    enabled = true,
}
_G[RUNTIME_KEY] = runtime

local function notify(text, style)
    if type(shared.Notify) == "function" then
        pcall(shared.Notify, text, style or 3)
    end
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- The Addons documentation requires the raw GitHub URL with its prefix and
-- .png suffix removed.
local ICON = "/ruvkr/milkyway/refs/heads/master/MilkyWay"

local tab = shared.CreateTab("Galaxy Milky Way", ICON)
local overview = tab:AddSection("✦ Galaxy Dashboard", "MILKY WAY UI")
local settings = tab:AddSection("☄️ Galaxy Settings", "COSMETIC CONTROLS")
local info = tab:AddSection("🌌 About", "CREDITS & STATUS")

local statusLabel = overview:AddLabel("Status: Online", true)
local playerLabel = overview:AddLabel("Player: " .. tostring(LocalPlayer and LocalPlayer.Name or "Unknown"), true)
local themeLabel = overview:AddLabel("Theme: Galaxy / Milky Way")

overview:AddParagraph(
    "Welcome to the Galaxy",
    "A clean Milky Way themed addon panel for Overdrive H. This addon only provides cosmetic UI and read-only status information."
)

local enabled = true
local toggle = settings:AddToggle("Enable Galaxy UI", function(state)
    enabled = state
    runtime.enabled = state
    statusLabel:SetValue("Status: " .. (state and "Online" or "Paused"))
    notify(state and "Galaxy UI enabled." or "Galaxy UI paused.", state and 2 or 0)
end)

settings:AddDropdown("Accent Preset", {"Nebula Purple", "Starlight Blue", "Aurora Cyan"}, function(selected)
    runtime.accent = selected
    notify("Accent preset: " .. selected, 3)
end)

settings:AddButton("Refresh Player Status", function()
    playerLabel:SetValue("Player: " .. tostring(LocalPlayer and LocalPlayer.Name or "Unknown"))
    notify("Galaxy status refreshed.", 2)
end)

info:AddLabel("Milky Way image: ruvkr/milkyway")
info:AddLabel("License: CC BY-SA 4.0")
info:AddLabel("Addon version: " .. runtime.version)
info:AddButton("Show Galaxy Credits", function()
    notify("Icon by ruvkr/milkyway — CC BY-SA 4.0.", 3)
end)

settings:AddKeybind("Toggle Galaxy UI", "G", function()
    if toggle then
        toggle()
    end
end)

notify("Galaxy Milky Way UI loaded.", 2)
