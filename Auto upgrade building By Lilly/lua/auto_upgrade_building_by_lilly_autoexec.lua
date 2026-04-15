local TIMER_NAME = "AutoUpgradeBuildingByLillyTick"
local TIMER_INTERVAL = 60.0
local AUTOEXEC_KEY = "auto_upgrade_building_by_lilly_autoexec.lua/"

local already_initialized = false
local timer_owner = INVALID_ID

local function is_server_side()
	return is_server == nil or is_server
end

local function find_first_alive_entity(blueprint_name)
	local entities = FindService:FindEntitiesByBlueprint(blueprint_name) or {}
	for _, entity in ipairs(entities) do
		if entity ~= nil and entity ~= INVALID_ID and EntityService:IsAlive(entity) then
			return entity
		end
	end

	return INVALID_ID
end

local function find_timer_owner_entity()
	local owner_blueprints = {
		"buildings/main/headquarters",
		"buildings/main/headquarters_lvl_2",
		"buildings/main/headquarters_lvl_3",
		"buildings/main/headquarters_lvl_4",
		"buildings/main/headquarters_lvl_5",
		"buildings/main/headquarters_lvl_6",
		"buildings/main/headquarters_lvl_7",
		"buildings/main/communications_hub",
		"buildings/main/communications_hub_lvl_2",
		"buildings/main/communications_hub_lvl_3",
		"buildings/main/communications_hub_lvl_4",
		"buildings/main/communications_hub_lvl_5",
	}

	for _, blueprint_name in ipairs(owner_blueprints) do
		local entity = find_first_alive_entity(blueprint_name)
		if entity ~= INVALID_ID then
			return entity
		end
	end

	return INVALID_ID
end

local function schedule_next_tick()
	if timer_owner == nil or timer_owner == INVALID_ID then
		return
	end

	QueueEvent("SetTimerRequest", timer_owner, TIMER_NAME, TIMER_INTERVAL)
end

local function ensure_timer_owner(entity)
	if entity == nil or entity == INVALID_ID then
		return false
	end

	if timer_owner == entity then
		return true
	end

	timer_owner = entity
	EntityService:CreateComponent(timer_owner, "TimerComponent")
	schedule_next_tick()
	LogService:Log("auto upgrade building: timer owner = " .. tostring(timer_owner))
	return true
end

local function try_initialize(fallback_entity)
	if not is_server_side() then
		return
	end

	local database = CampaignService:GetCampaignData()
	if database == nil then
		return
	end

	if not already_initialized then
		if not database:HasInt(AUTOEXEC_KEY) then
			database:SetInt(AUTOEXEC_KEY, 1)
		end
		already_initialized = true
	end

	local owner = find_timer_owner_entity()
	if owner == INVALID_ID then
		owner = fallback_entity or INVALID_ID
	end

	ensure_timer_owner(owner)
end

local function try_upgrade_all_buildings(reason)
	if not is_server_side() then
		return 0
	end

	local player_id = PlayerService:GetLeadingPlayer()
	if player_id == nil then
		return 0
	end

	local player_team = EntityService:GetTeam("player")
	local buildings = FindService:FindEntitiesByType("building") or {}
	local requested = 0

	for _, entity in ipairs(buildings) do
		if entity ~= nil and entity ~= INVALID_ID and EntityService:IsAlive(entity) and EntityService:GetTeam(entity) == player_team then
			QueueEvent("UpgradeBuildingRequest", entity, player_id)
			requested = requested + 1
		end
	end

	if requested > 0 then
		LogService:Log("auto upgrade building: requested " .. tostring(requested) .. " from " .. tostring(reason))
	end

	return requested
end

RegisterGlobalEventHandler("PlayerControlledEntityChangeEvent", function(evt)
	try_initialize(evt:GetEntity())
end)

RegisterGlobalEventHandler("MissionFlowDeactivatedEvent", function(_evt)
	try_initialize(timer_owner)
	try_upgrade_all_buildings("mission_flow_deactivated")
end)

RegisterGlobalEventHandler("StartBuildingEvent", function(evt)
	try_initialize(evt:GetEntity())
	try_upgrade_all_buildings("start_building")
end)

RegisterGlobalEventHandler("BuildingBuildEvent", function(evt)
	try_initialize(evt:GetEntity())
	try_upgrade_all_buildings("building_build")
end)

RegisterGlobalEventHandler("TimerElapsedEvent", function(evt)
	if evt:GetName() ~= TIMER_NAME then
		return
	end

	if timer_owner ~= nil and timer_owner ~= INVALID_ID then
		local event_entity = evt:GetEntity()
		if event_entity ~= nil and event_entity ~= INVALID_ID and event_entity ~= timer_owner then
			return
		end
	end

	try_upgrade_all_buildings("timer")
	schedule_next_tick()
end)
