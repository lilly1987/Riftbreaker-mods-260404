LogService:Log("start make rock")

-- Entity::Id   NOT-YET-WORKING-ASK-LUKASZ	SpawnEntity( IdString blueprint, const Vector3 & pos, const Quaternion & orient, TeamId team );
-- Entity::Id   SpawnEntity( const String & blueprint, const Vector3 & pos, TeamId team );
-- Entity::Id   SpawnEntity( const String & blueprint, float x, float y, float z, const String & team );
-- Entity::Id   SpawnEntity( const String & blueprint, const String & spawnPointName, const String & team );
-- Entity::Id   SpawnEntity( const String & blueprint, Entity::Id entity, const String & team );
-- Entity::Id   SpawnEntity( const String & blueprint, Entity::Id entity, TeamId team );
-- Entity::Id   SpawnEntity( const String & blueprint, Entity::Id entity, const String & attachment, const String & team );
-- Entity::Id   SpawnEntity( const String & blueprint, Entity::Id entity, const String & attachment, TeamId team );
-- Entity::Id   SpawnEntity( IdString blueprint, const Vector3 & pos, const Quaternion & orient );
-- Entity::Id   SpawnEntity( Entity::Id target );

local rock_prop = "props/rocks/cliff/cliff_small_01_lilly"
local rock_type = "path_blocker|cavern_wall|height_path_blocker|not_move_to_target|ignore_as_target|decorations"

LogService:Log("start make rock : ".. rock_prop .. " , " .. rock_type)

local WORLD_UNITS_PER_TILE = 2
local ROCK_SIZE_X_TILES = 3
local ROCK_SIZE_Z_TILES = 1
local OPENING_TILES = 4

local ROCK_SIZE_X = ROCK_SIZE_X_TILES * WORLD_UNITS_PER_TILE
local ROCK_SIZE_Z = ROCK_SIZE_Z_TILES * WORLD_UNITS_PER_TILE
local OPENING_SIZE = OPENING_TILES * WORLD_UNITS_PER_TILE

LogService:Log("start make rock : " .. ROCK_SIZE_X .. " , " .. ROCK_SIZE_Z .. " , " .. OPENING_SIZE)

local function spawnRock(x, z, rotation)
	local entity = EntityService:SpawnEntity(rock_prop, x, 1, z, "none")
	if entity ~= nil then
		if rotation ~= 0 then
			EntityService:Rotate(entity, 0, 1, 0, rotation)
		end

		EntityService:SetTeam(entity, "none")
		EntityService:ChangeType(entity, rock_type)

		local bounds = EntityService:GetBoundsSize(entity)
		local radius = math.max(bounds.x, bounds.z) * 0.5 + 1.0
		EntityService:CullNavMeshUnderEntity(entity, radius)
	end
end

local function overlapsOpening(center, segmentSize, openingCenter, openingSize)
	local segmentHalf = segmentSize * 0.5
	local openingHalf = openingSize * 0.5
	local segmentMin = center - segmentHalf
	local segmentMax = center + segmentHalf
	local openingMin = openingCenter - openingHalf
	local openingMax = openingCenter + openingHalf

	return segmentMin < openingMax and segmentMax > openingMin
end

RegisterGlobalEventHandler("PlayerControlledEntityChangeEvent", function(evt)
	LogService:Log("PlayerControlledEntityChangeEvent ST")

	local database = EntityService:GetDatabase(evt:GetControlledEntity())
	if database == nil then
		LogService:Log("database no")
		return
	end

	local key = "start_make_rock_autoexec.lua/"
	if database:HasInt(key) then
		LogService:Log("database has")
		return
	end

	database:SetInt(key, 1)
	LogService:Log("database set")

	-- ConsoleService:ExecuteCommand("r_show_map_info 1")
	-- ConsoleService:ExecuteCommand("cheat_reveal_minimap 1")

	local playable_max = MissionService:GetPlayableRegionMax()
	local playable_min = MissionService:GetPlayableRegionMin()
	local margin = tonumber(ConsoleService:GetConfig("map_non_playable_margin")) * WORLD_UNITS_PER_TILE

	LogService:Log("playable_max : " .. playable_max.x .. " , " .. playable_max.z)
	LogService:Log("playable_min : " .. playable_min.x .. " , " .. playable_min.z)
	LogService:Log("margin : " .. margin)

	local westX = playable_min.x + margin + (ROCK_SIZE_Z * 0.5)
	local eastX = playable_max.x - margin - (ROCK_SIZE_Z * 0.5)
	local southZ = playable_min.z + margin + (ROCK_SIZE_Z * 0.5)
	local northZ = playable_max.z - margin - (ROCK_SIZE_Z * 0.5)

	local minHorizontalCenter = playable_min.x + margin + (ROCK_SIZE_X * 0.5)
	local maxHorizontalCenter = playable_max.x - margin - (ROCK_SIZE_X * 0.5)
	local minVerticalCenter = playable_min.z + margin + (ROCK_SIZE_X * 0.5)
	local maxVerticalCenter = playable_max.z - margin - (ROCK_SIZE_X * 0.5)

	local centerX = (playable_min.x + playable_max.x) * 0.5
	local centerZ = (playable_min.z + playable_max.z) * 0.5

	for x = minHorizontalCenter, maxHorizontalCenter, ROCK_SIZE_X do
		if not overlapsOpening(x, ROCK_SIZE_X, centerX, OPENING_SIZE) then
			spawnRock(x, northZ, 90)
			spawnRock(x, southZ, 90)
		end
	end

	for z = minVerticalCenter, maxVerticalCenter, ROCK_SIZE_X do
		if not overlapsOpening(z, ROCK_SIZE_X, centerZ, OPENING_SIZE) then
			spawnRock(westX, z, 0)
			spawnRock(eastX, z, 0)
		end
	end

	LogService:Log("PlayerControlledEntityChangeEvent ED")
end)
