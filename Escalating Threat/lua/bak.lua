return

require("lua/utils/reflection.lua")

local MAX_SYSTEM_HEALTH = 99999
local HEALTH_INCREASE_PER_WAVE = 0.10
local MOD_DB_PREFIX = "escalating_threat."

local escalating_threat = {
    initialized = false,
    player_id = nil,
    enemy_team = nil,
    wave_enemy_team = nil,
    playable_min = nil,
    playable_max = nil,
    mission_key = "",
    wave_count = 0,
    base_health_by_entity = {},
    activated_wave_flows = {},
}

local function clamp(value, min_value, max_value)
    if value < min_value then
        return min_value
    end

    if value > max_value then
        return max_value
    end

    return value
end

function escalating_threat:RefreshMissionContext()
    self.enemy_team = EntityService:GetTeam("enemy")
    self.wave_enemy_team = EntityService:GetTeam("wave_enemy")
    self.playable_min = MissionService:GetPlayableRegionMin()
    self.playable_max = MissionService:GetPlayableRegionMax()
    self.mission_key = MissionService:GetCurrentMissionName() or CampaignService:GetCurrentMissionDefName() or "unknown_mission"
end

function escalating_threat:GetWaveCountDbKey()
    return MOD_DB_PREFIX .. self.mission_key .. ".wave_count"
end

function escalating_threat:LoadWaveCount()
    local database = CampaignService:GetCampaignData()
    if database == nil then
        self.wave_count = 0
        return
    end

    self.wave_count = database:GetIntOrDefault(self:GetWaveCountDbKey(), 0)
end

function escalating_threat:SaveWaveCount()
    local database = CampaignService:GetCampaignData()
    if database == nil then
        return
    end

    database:SetInt(self:GetWaveCountDbKey(), self.wave_count)
end

function escalating_threat:IsAttackMissionFlow(logic_name)
    if logic_name == nil or logic_name == "" then
        return false
    end

    if string.find(logic_name, "logic/missions/survival/", 1, true) ~= nil and string.find(logic_name, "attack", 1, true) ~= nil then
        return true
    end

    if string.find(logic_name, "logic/event/", 1, true) ~= nil and string.find(logic_name, "_attack", 1, true) ~= nil then
        return true
    end

    return false
end

function escalating_threat:GetHealthMultiplier()
    return 1.0 + (self.wave_count * HEALTH_INCREASE_PER_WAVE)
end

function escalating_threat:LogCurrentWaveSettings(logic_name)
    local multiplier = self:GetHealthMultiplier()
    local campaign_type = CampaignService:GetCurrentCampaignType() or "unknown"
    local line = string.format(
        "[Escalating Threat] mission=%s campaign_type=%s wave_logic=%s wave_count=%d health_multiplier=%.2f formula=base_health*(1+0.10*wave_count)",
        tostring(self.mission_key),
        tostring(campaign_type),
        tostring(logic_name),
        self.wave_count,
        multiplier
    )
    LogService:Log(line)
    ConsoleService:Write(line)
end

function escalating_threat:GetBaseHealthFromBlueprint(entity, fallback_health)
    local blueprint_database = EntityService:GetBlueprintDatabase(entity)
    if blueprint_database == nil then
        return fallback_health
    end

    local blueprint_max_health = blueprint_database:GetFloatOrDefault("max_health", 0.0)
    if blueprint_max_health ~= nil and blueprint_max_health > 0 then
        return blueprint_max_health
    end

    local blueprint_health = blueprint_database:GetFloatOrDefault("health", 0.0)
    if blueprint_health ~= nil and blueprint_health > 0 then
        return blueprint_health
    end

    return fallback_health
end

function escalating_threat:IsEnemyEntity(entity)
    if entity == nil or entity == INVALID_ID or EntityService:IsAlive(entity) ~= true then
        return false
    end

    local team = EntityService:GetTeam(entity)
    return team == self.enemy_team or team == self.wave_enemy_team
end

function escalating_threat:ApplyHealthScaling(entity)
    if not self:IsEnemyEntity(entity) then
        return
    end

    local health_component = EntityService:GetComponent(entity, "HealthComponent")
    if health_component == nil then
        return
    end

    local helper = reflection_helper(health_component)
    local current_max_health = helper.max_health
    local current_health = helper.health

    if current_max_health == nil or current_health == nil or current_max_health <= 0 then
        return
    end

    local base_health = self.base_health_by_entity[entity]

    if base_health == nil or base_health <= 0 or current_max_health < base_health then
        base_health = self:GetBaseHealthFromBlueprint(entity, current_max_health)
        self.base_health_by_entity[entity] = base_health
    end

    local multiplier = self:GetHealthMultiplier()
    if multiplier <= 1.0 then
        return
    end

    local target_max_health = math.floor(base_health * multiplier)
    target_max_health = clamp(target_max_health, base_health, MAX_SYSTEM_HEALTH)

    if target_max_health <= current_max_health then
        return
    end

    local current_ratio = current_health / current_max_health

    helper.max_health = target_max_health
    helper.health = math.max(1, math.floor(target_max_health * current_ratio))
end

function escalating_threat:ScanEnemies()
    if self.initialized ~= true then
        return
    end

    if self.playable_min == nil or self.playable_max == nil then
        self:RefreshMissionContext()
    end

    local predicate = {
        signature = "HealthComponent",
    }

    local entities = FindService:FindEntitiesByPredicateInBox(self.playable_min, self.playable_max, predicate)
    for entity in Iter(entities) do
        self:ApplyHealthScaling(entity)
    end
end

function escalating_threat:Initialize(evt)
    if evt ~= nil then
        self.player_id = evt:GetPlayerId()
    end

    self.base_health_by_entity = {}
    self.activated_wave_flows = {}

    self:RefreshMissionContext()
    self:LoadWaveCount()
    self.initialized = true
    self:ScanEnemies()
end

function escalating_threat:EnsureInitialized(evt)
    if self.initialized == true then
        return
    end

    self:Initialize(evt)
end

local function try_scan()
    escalating_threat:EnsureInitialized(nil)
    escalating_threat:ScanEnemies()
end

RegisterGlobalEventHandler("PlayerCreatedEvent", function(evt)
    escalating_threat:Initialize(evt)
end)

RegisterGlobalEventHandler("MissionFlowActivatedEvent", function(evt)
    escalating_threat:EnsureInitialized(nil)

    local ok, logic_name = pcall(function()
        return evt:GetName()
    end)

    if ok and escalating_threat:IsAttackMissionFlow(logic_name) then
        if escalating_threat.activated_wave_flows[logic_name] ~= true then
            escalating_threat.activated_wave_flows[logic_name] = true
            escalating_threat.wave_count = escalating_threat.wave_count + 1
            escalating_threat:SaveWaveCount()
            escalating_threat:LogCurrentWaveSettings(logic_name)
        end

        escalating_threat:ScanEnemies()
    end
end)

RegisterGlobalEventHandler("MissionFlowDeactivatedEvent", function(evt)
    escalating_threat:EnsureInitialized(nil)

    local ok, logic_name = pcall(function()
        return evt:GetName()
    end)

    if ok and logic_name ~= nil then
        escalating_threat.activated_wave_flows[logic_name] = nil
    end
end)

RegisterGlobalEventHandler("LuaGlobalEvent", function(_evt)
    try_scan()
end)

RegisterGlobalEventHandler("UnitAggressiveStateEvent", function(evt)
    escalating_threat:EnsureInitialized(nil)

    local ok, entity = pcall(function()
        return evt:GetEntity()
    end)

    if ok and entity ~= nil and entity ~= INVALID_ID then
        escalating_threat:ApplyHealthScaling(entity)
    else
        try_scan()
    end
end)

escalating_threat:EnsureInitialized(nil)
