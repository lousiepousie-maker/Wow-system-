-- Overdrive H updated loader for the latest script
-- This keeps compatibility with newer odh_shared_plugins API.
local shared = odh_shared_plugins

if not shared or type(shared.load_from_github_url) ~= "function" then
    return
end

shared.load_from_github_url("https://raw.githubusercontent.com/dogwiener24/Hi-bessi/refs/heads/main/Mm2.lua")
