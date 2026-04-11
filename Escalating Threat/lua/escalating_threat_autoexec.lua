require("lua/utils/reflection.lua")

local NOW_PER=0
local ADD_PER=0.125
local k1="escalating_threat_autoexec.lua" 

local function SetHealth(entity)
    if entity == nil or entity == INVALID_ID then
        return
    end
    if EntityService:IsAlive(entity) ~= true then
        return
    end
    local team = EntityService:GetTeam(entity)
    if team ~= EntityService:GetTeam("enemy") and team ~= EntityService:GetTeam("wave_enemy") then
        return
    end

    local blueprintDatabase = EntityService:GetBlueprintDatabase( ent )
    local max_health = blueprintDatabase:GetFloatOrDefault("max_health", 100.0)* (100+NOW_PER)/100 

    HealthService:SetMaxHealth( entity, max_health )
    HealthService:SetHealth(entity, max_health)
    local blueprintName = EntityService:GetBlueprintName(entity)
    LogService:Log("SetHealth " .. tostring(entity) .. " max_health: " .. tostring(max_health) .. " blueprint: " .. blueprintName)
    ConsoleService:Write("SetHealth " .. tostring(entity) .. " max_health: " .. tostring(max_health) .. " blueprint: " .. blueprintName)
end

RegisterGlobalEventHandler("PlayerCreatedEvent", function(evt)
    LogService:Log("PlayerCreatedEvent " )    
    -- ConsoleService:Write("PlayerCreatedEvent " )    
	local database = CampaignService:GetCampaignData()
    if ( database == nil ) then
        LogService:Log("database no")
        return
    end	
    NOW_PER = database:GetFloatOrDefault( k1, NOW_PER)
end)

	-- MissionFlowActivatedEvent logic/missions/survival/default.logic##000002157740C200##1
	-- PlayerCreatedEvent 
	-- MissionFlowActivatedEvent logic/utility/player_connected.logic##000002156A430C00##2
	-- MissionFlowDeactivatedEvent logic/utility/player_connected.logic##000002156A430C00##2
	-- NOW_PER : 0.125
	-- MissionFlowActivatedEvent logic/missions/survival/attack_level_1_id_2.logic##000002154B2F8D00##3
	-- MissionFlowActivatedEvent logic/dom/attack_level_1_entry.logic##000002154B2F0C00##4
	-- MissionFlowDeactivatedEvent logic/dom/attack_level_1_entry.logic##000002154B2F0C00##4
	-- NOW_PER : 0.25
	-- MissionFlowDeactivatedEvent logic/missions/survival/attack_level_1_id_2.logic##000002154B2F8D00##3
	-- NOW_PER : 0.375
	-- MissionFlowActivatedEvent objectivePrepareForTheAttacLogicFileName
	-- MissionFlowActivatedEvent logic/weather/wind_strong.logic##0000021575282000##5
	-- MissionFlowActivatedEvent logic/missions/survival/attack_level_1_id_2.logic##000002157527F600##6
	-- MissionFlowActivatedEvent logic/dom/attack_level_1_entry.logic##000002157527FF00##7
	-- MissionFlowDeactivatedEvent objectivePrepareForTheAttacLogicFileName
	-- NOW_PER : 0.5

RegisterGlobalEventHandler("MissionFlowActivatedEvent", function(evt)
    -- LogService:Log("MissionFlowActivatedEvent " .. evt:GetName())    
    -- ConsoleService:Write("MissionFlowActivatedEvent " .. evt:GetName( ))    
end)

local include_list = {
    -- "^logic/utility/player_connected",
    "^logic/missions/.*",
}

local function is_in_list(name)
    for _, pattern in ipairs(include_list) do
        if string.match(name, pattern) then
            return true
        end
    end
    return false
end

RegisterGlobalEventHandler("MissionFlowDeactivatedEvent", function(evt)
    -- LogService:Log("MissionFlowDeactivatedEvent " .. evt:GetName( ))    
    if not is_in_list(evt:GetName()) then
        return
    end
    -- ConsoleService:Write("MissionFlowDeactivatedEvent " .. evt:GetName( ))
	-----------------------------------------------
	local database = CampaignService:GetCampaignData()
    if ( database == nil ) then
        LogService:Log("database no")
        return
    end	
    NOW_PER = database:GetFloatOrDefault( k1, NOW_PER)+ADD_PER
    database:SetFloat( k1, NOW_PER)
    LogService:Log("NOW_PER : " .. NOW_PER)
	-----------------------------------------------
end)

-- ---
-- layout: default
-- title: UnitAggressiveStateEvent
-- nav_order: 1
-- has_children: true
-- parent: Lua services
-- ---
-- ### GetEntity
--  * (): [Entity const&](riftbreaker-wiki/docs/reflection/Entity const&) 
-- 작동 안함
RegisterGlobalEventHandler("UnitAggressiveStateEvent", function(evt)
    -- LogService:Log("UnitAggressiveStateEvent "  )    
    -- ConsoleService:Write("UnitAggressiveStateEvent " )
    SetHealth(evt:GetEntity())
end)

-- ---
-- layout: default
-- title: DamageEvent
-- nav_order: 1
-- has_children: true
-- parent: Lua services
-- ---
-- ### GetCreator
--  * (): [Entity const&](riftbreaker-wiki/docs/reflection/Entity const&)
  
-- ### GetDamageOverTime
--  * (): [bool const&](riftbreaker-wiki/docs/reflection/bool const&)
  
-- ### GetDamageType
--  * (): [string](riftbreaker-wiki/docs/reflection/string)
  
-- ### GetDamageValue
--  * (): [float const&](riftbreaker-wiki/docs/reflection/float const&)
  
-- ### GetEffect
--  * (): [enum DamageEffect const&](riftbreaker-wiki/docs/reflection/enum DamageEffect const&)
  
-- ### GetEntity
--  * (): [Entity const&](riftbreaker-wiki/docs/reflection/Entity const&)
  
-- ### GetOwner
--  * (): [Entity const&](riftbreaker-wiki/docs/reflection/Entity const&) 
RegisterGlobalEventHandler("DamageEvent", function(evt)
    -- LogService:Log("DamageEvent "  )    
    -- ConsoleService:Write(
    --     "DamageEvent " .. 
    --     EntityService:GetBlueprintName(evt:GetCreator()) .. 
    --     " / " .. evt:GetDamageValue() .. 
    --     " / " .. EntityService:GetBlueprintName(evt:GetEntity()) .. 
    --     " / " .. EntityService:GetBlueprintName(evt:GetOwner()) 
    -- )
end)


-- ---
-- layout: default
-- title: SpawnBlueprintOnTargetRequest
-- nav_order: 1
-- has_children: true
-- parent: Lua services
-- ---
-- ### GetAngle
--  * (): [float const&](riftbreaker-wiki/docs/reflection/float const&)
  
-- ### GetAxis
--  * (): [Math::Vector3<float> const&](riftbreaker-wiki/docs/reflection/Math::Vector3<float> const&)
  
-- ### GetBlueprint
--  * (): [string](riftbreaker-wiki/docs/reflection/string)
  
-- ### GetEntity
--  * (): [Entity const&](riftbreaker-wiki/docs/reflection/Entity const&)
  
-- ### GetTag
--  * (): [string](riftbreaker-wiki/docs/reflection/string) 
-- RegisterGlobalEventHandler("SpawnBlueprintOnTargetRequest", function(evt)
--     LogService:Log("SpawnBlueprintOnTargetRequest " .. evt:GetName( ))    
--     ConsoleService:Write("SpawnBlueprintOnTargetRequest " .. evt:GetName( ))
-- end)
