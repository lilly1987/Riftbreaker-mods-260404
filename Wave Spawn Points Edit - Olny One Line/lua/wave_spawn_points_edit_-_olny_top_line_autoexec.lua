LogService:Log("wave spawn points edit autoexec loaded")

local SCRIPT_KEY = "wave_spawn_points_edit_-_olny_top_line_autoexec.lua"
local BORDER_GROUPS =
{
	"spawn_enemy_border_north",
	"spawn_enemy_border_east",
	"spawn_enemy_border_south",
	"spawn_enemy_border_west",
}

local function getNonPlayableRegions()
	local playableMin = MissionService:GetPlayableRegionMin()
	local playableMax = MissionService:GetPlayableRegionMax()
	local margin = tonumber(ConsoleService:GetConfig("map_non_playable_margin"))

	return
	{
		["spawn_enemy_border_west"] =
		{
			min = { x = playableMin.x, y = -10, z = playableMin.z - margin },
			max = { x = playableMax.x, y = 10, z = playableMin.z }
		},
		["spawn_enemy_border_east"] =
		{
			min = { x = playableMin.x, y = -10, z = playableMax.z },
			max = { x = playableMax.x, y = 10, z = playableMax.z + margin }
		},
		["spawn_enemy_border_north"] =
		{
			min = { x = playableMax.x, y = -10, z = playableMin.z },
			max = { x = playableMax.x + margin, y = 10, z = playableMax.z }
		},
		["spawn_enemy_border_south"] =
		{
			min = { x = playableMin.x - margin, y = -10, z = playableMin.z },
			max = { x = playableMin.x, y = 10, z = playableMax.z }
		},
	}
end

local function clearWaveSpawnGroups()
	for _, groupName in ipairs(BORDER_GROUPS) do
		local entities = FindService:FindEntitiesByGroup(groupName)
		LogService:Log("wave spawn points edit clear " .. groupName .. " count=" .. tostring(#entities))

		for entity in Iter(entities) do
			EntityService:SetName(entity, "logic/spawn_enemy")
			EntityService:SetGroup(entity, "")
		end
	end
end

local function cloneNorthSpawnPointsToAllDirections()
	local regions = getNonPlayableRegions()
	local northBounds = regions["spawn_enemy_border_north"]
	local northEntities = FindService:FindEntitiesByBlueprintInBox("logic/spawn_enemy", northBounds.min, northBounds.max)

	if not Assert(#northEntities > 0, "wave spawn points edit failed to find north spawn points") then
		return
	end

	LogService:Log("wave spawn points edit north source count=" .. tostring(#northEntities))
	clearWaveSpawnGroups()

	for sourceEntity in Iter(northEntities) do
		local position = EntityService:GetPosition(sourceEntity)
		local cell = EnvironmentService:GetTerrainCell(position)

		if cell ~= INVALID_ID and not EntityService:HasComponent(cell, "WorldBlockerLayerComponent") then
			for _, groupName in ipairs(BORDER_GROUPS) do
				local entity = EntityService:SpawnEntity("logic/spawn_enemy", position.x, position.y, position.z, "")
				EntityService:SetName(entity, groupName .. "/" .. tostring(entity))
				EntityService:SetGroup(entity, groupName)
				EntityService:SpawnAndAttachEntity("logic/spawn_enemy_grid_culler", entity)
			end
		end
	end

	LogService:Log("wave spawn points edit applied north-only spawn layout")
end

RegisterGlobalEventHandler("PlayerControlledEntityChangeEvent", function(evt)
	LogService:Log("wave spawn points edit PlayerControlledEntityChangeEvent")

	local controlledEntity = evt:GetControlledEntity()
	local database = EntityService:GetDatabase(controlledEntity)
	if database == nil then
		LogService:Log("wave spawn points edit no entity database")
		return
	end

	if database:HasInt(SCRIPT_KEY) then
		LogService:Log("wave spawn points edit already applied")
		return
	end

	database:SetInt(SCRIPT_KEY, 1)
	cloneNorthSpawnPointsToAllDirections()
end)
