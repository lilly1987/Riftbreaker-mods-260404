
-- 안됨
-- require("lua/buildings/building_base.lua")

-- local old_building_base_init = building_base.init

-- function building_base:init()
--     LogService:Log("building_base:init() called")
--     ConsoleService:Write("building_base:init() called")
--     old_building_base_init(self)

--     self.extendLength = 0.1
--     self.buildingMultiplier = 0.1
--     self.buildingTime = 0.1
--     self.endCubeEnt =nil
-- end

-- function building_base:OnStartBuildingEvent()
--     LogService:Log("building_base:OnStartBuildingEvent() called")
--     ConsoleService:Write("building_base:OnStartBuildingEvent() called")
--     self.extendLength = 0.1
--     self.buildingMultiplier = 0.1
--     self.buildingTime = 0.1
--     self.endCubeEnt =nil
-- 	self:OnBuildingStart()
-- end

-- function building_base:_OnBigBuildingEnterState1( state )
--     state:SetDurationLimit( self.extendLength )
-- 	self:_CreateLine(self.cubeEnt, self.endCubeEnt, 0, 1 )
-- 	self:_CreateLine(self.cubeEnt, self.endCubeEnt, 1, 1 )
-- 	self:_CreateLine(self.cubeEnt, self.endCubeEnt, 2, 1 )
	
-- 	EffectService:SpawnEffect( self.entity, "effects/buildings_and_machines/building_cube_line_expand_sound" )
-- 	--LogService:Log("_OnBigBuildingEnter1" )
-- end

-- function building_base:_OnBigBuildingEnterState2( state )
--     state:SetDurationLimit( self.extendLength )
-- 	local i = 0
-- 	for cube in Iter( self.currentCubes ) do 
-- 		if ( i == 0 ) then
-- 			self:_CreateLine(cube, self.endCubeEnt, 1, 1 )
-- 			self:_CreateLine(cube, self.endCubeEnt, 2, 1 )
-- 		elseif ( i == 1) then
-- 			self:_CreateLine(cube, self.endCubeEnt, 0, 1 )
-- 			self:_CreateLine(cube, self.endCubeEnt, 2, 1 )
-- 		elseif ( i == 2 ) then
-- 			self:_CreateLine(cube, self.endCubeEnt, 0, 1 )
-- 			self:_CreateLine(cube, self.endCubeEnt, 1, 1 )
-- 		end		
-- 		i = i + 1 
-- 	end
	
-- 	EffectService:SpawnEffect( self.entity, "effects/buildings_and_machines/building_cube_line_expand_sound" )
-- 	--LogService:Log("_OnBigBuildingEnter2" )
-- end