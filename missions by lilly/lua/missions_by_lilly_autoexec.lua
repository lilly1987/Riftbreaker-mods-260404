-- 안됨

LogService:Log("missions by lilly" 
.. ' / ' .. tostring(DifficultyService:GetWarmupDuration())
.. ' / ' .. tostring(DifficultyService:IsMissionInfinite())
.. ' / ' .. tostring(DifficultyService:GetMissionDuration())
.. ' / ' .. tostring(DifficultyService:IdleTimeMultiplier())
.. ' / ' .. tostring(DifficultyService:GetWaveStrength())
.. ' / ' .. tostring(DifficultyService:GetWaveIntermissionTime())
.. ' / ' .. tostring(DifficultyService:GetWaveIntermissionMultiplier())
.. ' / ' .. tostring(DifficultyService:GetAttacksCountMultiplier())
.. ' / ' .. tostring(DifficultyService:GetWaveCooldownPerPlayerFactor())
.. ' / ' .. tostring(DifficultyService:GetPrepareAttackTimeMultiplier())
.. ' / ' .. tostring(DifficultyService:GetBuildingSpeedMultiplier())
)

require("lua/utils/reflection.lua")

local SCRIPT_KEY = "missions_by_lilly_autoexec.lua"
local TARGET_FRAGMENT = "missions/survival/jungle"
local TARGET_MAP_SIZE = 4

local function try_patch_jungle_map_size(reason)
    local missionDefName = CampaignService:GetCurrentMissionDefName()
    if missionDefName == nil or missionDefName == "" then
        LogService:Log(SCRIPT_KEY .. " [" .. reason .. "] mission def name is empty")
        return
    end

    -- local missionDefNameLower = string.lower(missionDefName)
    -- if string.find(missionDefNameLower, TARGET_FRAGMENT, 1, true) == nil then
    --     return
    -- end

    local missionDef = ResourceManager:GetResource("MissionDef", missionDefName)
    if missionDef == nil then
        LogService:Log(SCRIPT_KEY .. " [" .. reason .. "] MissionDef not found: " .. missionDefName)
        return
    end

    local missionDefHelper = reflection_helper(missionDef)
    local mapSize = missionDefHelper.map_size
    if mapSize == nil then
        LogService:Log(SCRIPT_KEY .. " [" .. reason .. "] map_size field not found")
        return
    end

    local oldX = tonumber(mapSize.x or 0)
    local oldY = tonumber(mapSize.y or 0)
    if oldX == TARGET_MAP_SIZE and oldY == TARGET_MAP_SIZE then
        LogService:Log(SCRIPT_KEY .. " [" .. reason .. "] jungle map_size already " .. tostring(TARGET_MAP_SIZE) .. "x" .. tostring(TARGET_MAP_SIZE))
        return
    end

    mapSize.x = TARGET_MAP_SIZE
    mapSize.y = TARGET_MAP_SIZE
    LogService:Log(
        SCRIPT_KEY
            .. " [" .. reason .. "] "
            .. missionDefName
            .. " map_size "
            .. tostring(oldX) .. "x" .. tostring(oldY)
            .. " -> "
            .. tostring(TARGET_MAP_SIZE) .. "x" .. tostring(TARGET_MAP_SIZE)
    )
end

try_patch_jungle_map_size("autoexec_load")

-- RegisterGlobalEventHandler("PlayerCreatedEvent", function(_evt)
--     try_patch_jungle_map_size("PlayerCreatedEvent")
-- end)

-- RegisterGlobalEventHandler("PlayerInitializedEvent", function(_evt)
--     try_patch_jungle_map_size("PlayerInitializedEvent")
-- end)

-- RegisterGlobalEventHandler("PlayerControlledEntityChangeEvent", function(_evt)
--     try_patch_jungle_map_size("PlayerControlledEntityChangeEvent")
-- end)

-- RegisterGlobalEventHandler("MissionFlowActivatedEvent", function(_evt)
--     try_patch_jungle_map_size("MissionFlowActivatedEvent")
-- end)
