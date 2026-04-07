LogService:Log("start make gate, trap")

-- 게임 기준: 1칸 = 월드 좌표 2.
local CELL_WORLD_SIZE = 2

local function B(blueprint, cells)
	return { blueprint = blueprint, cells = cells }
end

-- mode:
--   "first"  = 목록의 첫 건물만 반복 배치
--   "random" = 목록에서 랜덤 선택
--   "cycle"  = 목록 순서대로 하나씩 반복 선택
--   "layer_cycle" = 겹마다 목록 순서대로 하나씩 선택
--
-- repeat_count:
--   같은 layer를 바깥쪽으로 몇 겹 반복할지 정한다.
local LAYERS = {
	{
		name = "gates",
		mode = "first",
		repeat_count = 1,
		buildings = {
			B("buildings/defense/wall_gate_energy_lvl_3", 2),
		},
		rotations = { north = nil, south = 180, west = 90, east = 270 },
	},
	{
		name = "walls",
		mode = "layer_cycle",
		repeat_count = 3,
		buildings = {
			B("buildings/defense/wall_vine_straight_01_lvl_3", 1),
			B("buildings/defense/wall_energy_x_01_lvl_3", 1),
			B("buildings/defense/wall_crystal_x_01_lvl_3", 1),
		},
		rotations = { north = nil, south = nil, west = nil, east = nil },
	},
	{
		name = "traps",
		mode = "random",
		repeat_count = 1,
		buildings = {
			B("buildings/defense/trap_acid", 2),
			B("buildings/defense/trap_energy", 2),
			B("buildings/defense/trap_fire", 2),
			B("buildings/defense/trap_physical", 2),
			B("buildings/defense/trap_cryo", 2),
			B("buildings/defense/trap_area", 2),
		},
		rotations = { north = nil, south = nil, west = nil, east = nil },
	},


}

local function CellsToWorld(cells)
	return cells * CELL_WORLD_SIZE
end

local function GetLayerStep(layer)
	return CellsToWorld(layer.buildings[1].cells or 1)
end

local function PickBuilding(layer, index, repeat_index)
	if layer.mode == "random" then
		return layer.buildings[math.random(#layer.buildings)]
	end

	if layer.mode == "layer_cycle" then
		local building_index = ((repeat_index - 1) % #layer.buildings) + 1
		return layer.buildings[building_index]
	end

	if layer.mode == "cycle" then
		local building_index = ((index - 1) % #layer.buildings) + 1
		return layer.buildings[building_index]
	end

	return layer.buildings[1]
end

local function SpawnBuilding(building, x, z, rotation)
	local entity = EntityService:SpawnEntity(building.blueprint, x, 0, z, "")
	if rotation ~= nil then
		EntityService:Rotate(entity, 0, 1, 0, rotation)
	end

	return entity
end

local function SpawnLayerLine(layer, x1, z1, x2, z2, rotation, repeat_index)
	local step = GetLayerStep(layer)
	local index = 1

	if x1 == x2 then
		local direction = z1 <= z2 and 1 or -1
		for z = z1, z2, step * direction do
			SpawnBuilding(PickBuilding(layer, index, repeat_index), x1, z, rotation)
			index = index + 1
		end
	else
		local direction = x1 <= x2 and 1 or -1
		for x = x1, x2, step * direction do
			SpawnBuilding(PickBuilding(layer, index, repeat_index), x, z1, rotation)
			index = index + 1
		end
	end
end

local function GetPlayableBounds()
	local playable_min = MissionService:GetPlayableRegionMin()
	local playable_max = MissionService:GetPlayableRegionMax()
	local margin = tonumber(ConsoleService:GetConfig("map_non_playable_margin")) * CELL_WORLD_SIZE

	LogService:Log(" playable_max : " .. playable_max.x .. " , " .. playable_max.z)
	LogService:Log(" playable_min : " .. playable_min.x .. " , " .. playable_min.z)
	LogService:Log(" margin : " .. margin)

	return {
		xmin = playable_min.x + margin + CellsToWorld(1),
		xmax = playable_max.x - margin - CellsToWorld(1),
		zmin = playable_min.z + margin - CellsToWorld(1),
		zmax = playable_max.z - margin + CellsToWorld(1),

		north_x = playable_max.x - margin + CellsToWorld(1),
		south_x = playable_min.x + margin - CellsToWorld(1),
		west_z = playable_min.z + margin - CellsToWorld(1),
		east_z = playable_max.z - margin + CellsToWorld(1),
	}
end

local function SpawnLayer(bounds, layer, offset, repeat_index)
	local rotations = layer.rotations or {}

	-- offset이 커질수록 플레이 가능 영역 바깥쪽으로 한 겹씩 확장된다.
	SpawnLayerLine(layer, bounds.north_x + offset, bounds.zmin - offset, bounds.north_x + offset, bounds.zmax + offset, rotations.north, repeat_index)
	SpawnLayerLine(layer, bounds.south_x - offset, bounds.zmin - offset, bounds.south_x - offset, bounds.zmax + offset, rotations.south, repeat_index)
	SpawnLayerLine(layer, bounds.xmin - offset, bounds.west_z - offset, bounds.xmax + offset, bounds.west_z - offset, rotations.west, repeat_index)
	SpawnLayerLine(layer, bounds.xmin - offset, bounds.east_z + offset, bounds.xmax + offset, bounds.east_z + offset, rotations.east, repeat_index)
end

local function SpawnPerimeter(bounds)
	local offset = 0

	for _, layer in ipairs(LAYERS) do
		local repeat_count = layer.repeat_count or 1
		local layer_step = GetLayerStep(layer)

		for i = 1, repeat_count do
			LogService:Log(" spawn layer : " .. layer.name .. " #" .. tostring(i) .. " offset " .. tostring(offset))
			SpawnLayer(bounds, layer, offset, i)
			offset = offset + layer_step
		end
	end
end

RegisterGlobalEventHandler("PlayerControlledEntityChangeEvent", function(evt)
	LogService:Log("PlayerControlledEntityChangeEvent ST")

	local database = EntityService:GetDatabase( evt:GetControlledEntity() )
	if ( database == nil ) then
		LogService:Log("database no" )
		return
	end

	local key = "start_make_gate_autoexec.lua/"
	if database:HasInt( key ) then
		LogService:Log(" database has " )
		return
	end

	database:SetInt( key, 1 )
	LogService:Log(" database set " )

	SpawnPerimeter(GetPlayableBounds())

	LogService:Log("PlayerControlledEntityChangeEvent ED")
end)
