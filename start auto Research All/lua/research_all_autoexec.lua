local AUTOEXEC_KEY = "research_all_autoexec.lua/"
local already_applied = false
local requested_researches = {}
local total_unlocked = 0

local function unlock_research(research_id)
	if research_id == nil or research_id == "" then
		return false
	end

	if requested_researches[research_id] then
		return false
	end

	requested_researches[research_id] = true
	PlayerService:EnableResearch(research_id)
	PlayerService:UnlockResearch(research_id)
	total_unlocked = total_unlocked + 1
	return true
end

local function unlock_available_researches_once()
	local research_list = PlayerService:GetResearchesAvailableToUnlockList(false)
	if research_list == nil or #research_list == 0 then
		return 0
	end

	local unlocked = 0
	for _, research_id in ipairs(research_list) do
		if unlock_research(research_id) then
			unlocked = unlocked + 1
		end
	end

	return unlocked
end

local function try_apply_once()
	if already_applied then
		return
	end

	local campaign_type = CampaignService:GetCurrentCampaignType()
	LogService:Log("research all: campaign type = " .. tostring(campaign_type))
	if campaign_type ~= "survival" then
		return
	end

	local database = CampaignService:GetCampaignData()
	if database == nil then
		LogService:Log("research all: campaign data not ready")
		return
	end

	if database:HasInt(AUTOEXEC_KEY) then
		already_applied = true
		LogService:Log("research all: already applied")
		return
	end

	database:SetInt(AUTOEXEC_KEY, 1)
	already_applied = true
	local unlocked = unlock_available_researches_once()
	LogService:Log("research all: initial unlocked count = " .. tostring(unlocked))
	ConsoleService:Write("research all: initial unlocked count = " .. tostring(unlocked))
end

RegisterGlobalEventHandler("MissionFlowDeactivatedEvent", function(_evt)
	try_apply_once()
end)

RegisterGlobalEventHandler("NewResearchAvailableEvent", function(evt)
	if not already_applied then
		return
	end

	local research_id = evt:GetName()
	if unlock_research(research_id) then
		LogService:Log("research all: unlocked new research = " .. tostring(research_id) .. ", total = " .. tostring(total_unlocked))
	end
end)

RegisterGlobalEventHandler("ResearchUnlockedEvent", function(evt)
	if not already_applied then
		return
	end

	LogService:Log("research all: confirmed unlock = " .. tostring(evt:GetName()) .. ", total = " .. tostring(total_unlocked))
end)
