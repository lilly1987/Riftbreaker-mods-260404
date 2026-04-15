local TIMER_NAME = "AutoAddingToResearchQueueByLillyTick"
local TIMER_INTERVAL = 60.0
local AUTOEXEC_KEY = "auto_adding_to_research_queue_by_lilly_autoexec.lua/"

local already_initialized = false
local timer_owner = INVALID_ID
local queued_researches = {}

local function is_server_side()
	return is_server == nil or is_server
end

local function has_communications_hub()
	local hub_names = {
		"communications_hub",
		"communications_hub_lvl_2",
		"communications_hub_lvl_3",
		"communications_hub_lvl_4",
		"communications_hub_lvl_5",
	}

	for _, name in ipairs(hub_names) do
		local blueprint_name = "buildings/main/" .. name
		if BuildingService:HasBuildingWithBp(blueprint_name) then
			return true
		end

		if BuildingService:GetBuildingByBpCount(blueprint_name) > 0 then
			return true
		end

		if BuildingService:GetGlobalBuildingByNameCount(name) > 0 then
			return true
		end
	end

	return false
end

local function schedule_next_tick()
	if timer_owner == nil or timer_owner == INVALID_ID then
		return
	end

	QueueEvent("SetTimerRequest", timer_owner, TIMER_NAME, TIMER_INTERVAL)
end

local function queue_available_researches(reason)
	if not is_server_side() then
		return 0
	end

	if not has_communications_hub() then
		return 0
	end

	local player_id = PlayerService:GetLeadingPlayer()
	if player_id == nil then
		return 0
	end

	local researches = PlayerService:GetResearchesAvailableToUnlockList(false)
	if researches == nil or #researches == 0 then
		return 0
	end

	local added = 0
	for _, research_name in ipairs(researches) do
		if research_name ~= nil and research_name ~= "" and not queued_researches[research_name] then
			QueueEvent("AddToResearchRequest", INVALID_ID, research_name, player_id)
			added = added + 1
		end
	end

	if added > 0 then
		LogService:Log("auto research queue: added " .. tostring(added) .. " from " .. tostring(reason))
	end

	return added
end

local function ensure_timer_owner(entity)
	if entity == nil or entity == INVALID_ID then
		return false
	end

	timer_owner = entity
	EntityService:CreateComponent(timer_owner, "TimerComponent")
	schedule_next_tick()
	return true
end

local function try_initialize(timer_entity)
	if not is_server_side() then
		return
	end

	if already_initialized then
		if timer_entity ~= nil and timer_entity ~= INVALID_ID and (timer_owner == nil or timer_owner == INVALID_ID) then
			ensure_timer_owner(timer_entity)
		end
		return
	end

	local database = CampaignService:GetCampaignData()
	if database == nil then
		return
	end

	if database:HasInt(AUTOEXEC_KEY) then
		already_initialized = true
	else
		database:SetInt(AUTOEXEC_KEY, 1)
		already_initialized = true
	end

	ensure_timer_owner(timer_entity)
	queue_available_researches("init")
end

-- 1번째
RegisterGlobalEventHandler("PlayerInitializedEvent", function(_evt)
	-- LogService:Log("PlayerInitializedEvent")
	try_initialize(timer_owner)
	queue_available_researches("player_initialized")
end)

-- 2번째
RegisterGlobalEventHandler("PlayerControlledEntityChangeEvent", function(evt)
	-- LogService:Log("PlayerControlledEntityChangeEvent: " .. tostring(evt:GetEntity()))
	try_initialize(evt:GetEntity())
end)

-- 3번째
RegisterGlobalEventHandler("TimerElapsedEvent", function(evt)
	if evt:GetName() ~= TIMER_NAME then
		return
	end
	-- LogService:Log("TimerElapsedEvent: " .. tostring(evt:GetName()))

	queue_available_researches("timer")
	schedule_next_tick()
end)

-- 4번째
RegisterGlobalEventHandler("MissionFlowDeactivatedEvent", function(_evt)
	-- LogService:Log("MissionFlowDeactivatedEvent")
	try_initialize(timer_owner)
	queue_available_researches("mission_flow_deactivated")
end)

RegisterGlobalEventHandler("StartBuildingEvent", function(evt)
	-- LogService:Log("StartBuildingEvent: " .. tostring(evt:GetEntity()))
	try_initialize(evt:GetEntity())
	queue_available_researches("start_building")
end)

RegisterGlobalEventHandler("BuildingBuildEvent", function(evt)
	-- LogService:Log("BuildingBuildEvent: " .. tostring(evt:GetEntity()))
	try_initialize(evt:GetEntity())
	queue_available_researches("building_build")
end)

RegisterGlobalEventHandler("NewResearchAvailableEvent", function(evt)
	queue_available_researches("new_research_available:" .. tostring(evt:GetName()))
end)

RegisterGlobalEventHandler("AddedToResearchEvent", function(evt)
	queued_researches[evt:GetName()] = true
	queue_available_researches("added_to_queue:" .. tostring(evt:GetName()))
end)

RegisterGlobalEventHandler("ResearchUnlockedEvent", function(evt)
	queued_researches[evt:GetName()] = true
	queue_available_researches("research_unlocked:" .. tostring(evt:GetName()))
end)
