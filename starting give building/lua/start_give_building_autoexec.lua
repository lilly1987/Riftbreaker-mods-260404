local defenses={
"buildings/defense/tower_flamer_lvl_3"   ,
"buildings/defense/tower_laser_lvl_3"        ,
"buildings/defense/tower_lightning_lvl_3"    ,
"buildings/defense/tower_minigun_lvl_3"      ,
"buildings/defense/tower_plasma_lvl_3"       ,
"buildings/defense/tower_railgun_lvl_3"      ,
"buildings/defense/tower_shockwave_lvl_3"    ,
"buildings/defense/tower_shotgun_lvl_3"      ,
"buildings/defense/tower_acid_spitter_lvl_3" ,
--"buildings/defense/tower_gatling_laser_lvl_3"
}
local list={
	--{ "buildings/main/headquarters_lvl_7" , 1},--err
	--{ "buildings/defense/short_range_radar_lvl_3" , 1},
	
	{ "buildings/energy/energy_pylon" , 1,1},
	{ "buildings/defense/ai_hub_lvl_3" , 4,1},
	
	{ "buildings/energy/energy_storage_lvl_3" , 4 ,0},
	{ "buildings/resources/ammunition_storage_lvl_3" , 4,0},
	
	{ "buildings/main/armory_lvl_5" , 5,3},
	--{ "buildings/main/communications_hub_lvl_5" , 5,10},
	
	{ "buildings/defense/repair_facility_lvl_3" , 16,0},
	--{ "buildings/resources/carbonium_factory_lvl_3" , 4},
	--{ "buildings/resources/steel_factory_lvl_3" , 4},
	--{ "buildings/resources/rare_element_mine_lvl_3" , 4},	
	
	{ "buildings/resources/flora_collector_lvl_3" , 4,3},
	--{ "buildings/resources/liquid_pump_lvl_3" , 4},
	
	{ "buildings/resources/drone_mine_lvl_3" , 4,3},
	{ "buildings/resources/loot_collector_lvl_3" , 4,3},
	
	
	{ "buildings/resources/tower_ammunition_factory_lvl_3" , 4,2},
	
	--{ "buildings/energy/solar_panels_lvl_3" , 32},
	--{ "buildings/energy/wind_turbine_lvl_3" , 32},
	--{ "buildings/energy/energy_connector" , 16},
}

--std::pair<bool, Exor::Vector3 >  	FindEmptySpotInRadius( Exor::Entity::Id ent, float radius, const Exor::String & typeCheck, const Exor::String & excludedTerrainType );
--std::pair<bool, Exor::Vector3 >  	FindEmptySpotInRadius( Exor::Entity::Id ent, float minRadius, float maxRadius , const Exor::String & typeCheck, const Exor::String & excludedTerrainType );
--std::pair<bool, Exor::Vector3 >  	FindEmptySpotInRadius( Exor::Entity::Id ent, float minRadius, float maxRadius, const Exor::String & typeCheck, const Exor::String & excludedTerrainType, float minBorderDistance, float maxBorderDistance );
--Exor::Vector<Exor::Vector3 >     	FindEmptySpotsInRadius( Exor::Entity::Id ent, float minRadius, float maxRadius, const Exor::String & typeCheck, const Exor::String & excludedTerrainType );
--Exor::Vector<Exor::Vector3 >     	FindEmptySpotsInRadius( Exor::Entity::Id ent, float minRadius, float maxRadius, const Exor::String & typeCheck, const Exor::String & excludedTerrainType, float minBorderDistance, float maxBorderDistance );
--Exor::Vector<Exor::Vector3 >     	FindEmptySpotsInRadius( Exor::Entity::Id ent, float minRadius, float maxRadius, const Exor::String & typeCheck, const Exor::String & excludedTerrainType, float minBorderDistance, float maxBorderDistance, size_t count );
--Exor::Vector<Exor::Vector3 >     	FindSpotsInBounds( Exor::Entity::Id ent, const Exor::String & typeCheck, const Exor::String & excludedTerrainType );
--std::pair<bool, Exor::Vector3>   	FindEmptyCultivatorSpotInRadius( Exor::Entity ent, float radius, const Exor::String & typeCheck, const Exor::String & excludedTerrainType );
--FindEntityByBlueprintInDistance( Entity::Id entity, const char * blueprint, float radius );
local SpawnEntity=function (name,x,y,z,team)
	local position={x=x,y=y,z=z}
	-- GetTerrainHeight( const Vector3 & pos )
	position.y = EnvironmentService:GetTerrainHeight(position)
	return EntityService:SpawnEntity( name,position.x,position.y,position.z,team )
end

local defenseSpawn=function(Position,resources)
	local defense=nil
	local entity = EnvironmentService:GetTerrainCell( Position )
	local BlueprintName=EntityService:GetBlueprintName(entity)
	--LogService:Log("entity : " .. BlueprintName) -- ""
	--if EntityService:HasComponent( entity, "WaterLayerComponent" ) then
	--	local Component=EntityService:GetComponent(entity,"WaterLayerComponent")
	--	local water_height=Component:GetField("water_height"):GetValue()
	--	--LogService:Log("water_height : " .. water_height)
	--	Position.y=tonumber(water_height)
	--	--LogService:Log("TerrainType : " .. EnvironmentService:GetTerrainTypeUnderEntity(entity)) -- "" 
	--	--LogService:Log("TerrainType : " .. EntityService:GetResourceAmount(entity).first) -- "" 
	if resources=="morphium" then
		defense="buildings/defense/tower_alien_influence_lvl_3"
		Position.x=Position.x+2
	elseif 	resources=="mud" 
	or 		resources=="magma" 
	or 		resources=="sludge" 
	or 		resources=="water" 
	then
		defense="buildings/defense/tower_water_basic_lvl_3"
	else
		defense=defenses[ math.random( #defenses ) ]
	end
	return EntityService:SpawnEntity( defense, Position.x , Position.y , Position.z , "")
end

local f_distribution_radius=function()
	local name="buildings/energy/energy_connector"
    local Blueprint = ResourceManager:GetBlueprint( name )
    if ( Blueprint == nil ) then
        LogService:Log("NOT EXISTS 1 : " .. name)
        return 4
    end
    local Component = Blueprint:GetComponent("ResourceStorageComponent")
    if ( Component == nil ) then
        LogService:Log("NOT EXISTS 2 : " .. "ResourceStorageComponent")
        return 4
    end
    local Container = Component:GetField("Storages"):ToContainer()
    if ( Container == nil ) then
        LogService:Log("NOT EXISTS 3 : " .. "Storages")
        return 4
    end
	
	local f=nil
	local item=nil
	local n=0
	
    for i=0,Container:GetItemCount()-1 do	
        item = Container:GetItem(i)
		if ( item ~= nil ) then	
			f=item:GetField("distribution_radius")
			if ( f ~= nil ) then	
				n=tonumber(f:GetValue())
				LogService:Log(name .. " : " .. n)
				return n			
			end		
		end
    end	
	return 4
end

local energy=function(Position,cnt2)
	for i=1,cnt2 do
		EntityService:SpawnEntity( "buildings/energy/solar_panels_lvl_3", Position.x , Position.y , Position.z , "")
		EntityService:SpawnEntity( "buildings/energy/wind_turbine_lvl_3", Position.x , Position.y , Position.z , "")
	end
end

--std::pair<bool, Exor::Vector3 >  	FindEmptySpotInRadius( Exor::Entity::Id ent, float radius                     , const Exor::String & typeCheck, const Exor::String & excludedTerrainType );
--std::pair<bool, Exor::Vector3 >  	FindEmptySpotInRadius( Exor::Entity::Id ent, float minRadius, float maxRadius , const Exor::String & typeCheck, const Exor::String & excludedTerrainType );
-- energy_connector(tEntity,distribution_radius)
local energy_connector=function(tEntity,distribution_radius)
	local spot=FindService:FindEmptySpotInRadius(tEntity, distribution_radius-1, distribution_radius+1,"","")
	--spot=FindService:FindEmptySpotForBuildingRadius(tEntity,  distribution_radius,"buildings/energy/energy_connector","","")
	if spot.first then
		local Position=spot.second
		--LogService:Log(" Position : x : " .. Position.x .. " , y : " .. Position.y .. " , z : " .. Position.z)				
		EntityService:SpawnEntity( "buildings/energy/energy_connector", Position.x , Position.y , Position.z , "")
	end
end

local mySpawnEntity=function(Player, search_radius,distribution_radius, resources, make, cnt1,cnt2)
	local Entities = FindService:FindEntitiesByPredicateInRadius( Player, search_radius, {
		type="",
		signature="ResourceComponent,GridMarkerComponent",		
		filter = function(entity) 
			--if string.find(EntityService:GetBlueprintName(entity), resources) ~=nil then
			if EntityService:GetResourceAmount(entity).first ~= resources then
                return false
            end
			--LogService:Log( " resources : " .. resources .. " ; " .. make .. " , " .. (EntityService:GetResourceAmount(entity).first))
			--local Position=EntityService:GetPosition(entity)
			--LogService:Log(" Position : x : " .. Position.x .. " , y : " .. Position.y .. " , z : " .. Position.z .. " , " .. tostring(FindService:IsGridMarkedWithLayer(Position, "OwnerLayerComponent")) .. " , " .. tostring(EntityService:GetResourceAmount(entity).first))
			return true
		end
	});
	--for _,fEntity in pairs( Entities ) do
	--	LogService:Log( " Blueprint : " .. EntityService:GetBlueprintName(fEntity))
	--end
	local n=0
	local tEntity=nil
	local Position=nil
	for i=1,cnt1 do
		if #Entities >0 then
			n=math.random( #Entities )
			tEntity=Entities[ n ]
			Position=EntityService:GetPosition(tEntity)
			tEntity=EntityService:SpawnEntity( make, Position.x , Position.y , Position.z , "")
			energy(Position,cnt2)
			energy_connector(tEntity,distribution_radius)
			defenseSpawn(Position,resources)
			table.remove(Entities, n)
		else
			return
		end
	end
end

local chack=function(Player, search_radius)
	local Entities = FindService:FindEntitiesByPredicateInRadius( Player, search_radius, {
		type="",
		signature="ResourceComponent,GridMarkerComponent",		
		filter = function(entity) 
			--LogService:Log( " resources : " .. resources)
			if EntityService:GetResourceAmount(entity).first == "carbonium"
			or EntityService:GetResourceAmount(entity).first == "steel"		
			or EntityService:GetResourceAmount(entity).first == "cobalt"		
			or EntityService:GetResourceAmount(entity).first == "palladium"
			or EntityService:GetResourceAmount(entity).first == "uranium_ore"			
			or EntityService:GetResourceAmount(entity).first == "titanium"	
			or EntityService:GetResourceAmount(entity).first == "geothermal"	
			or EntityService:GetResourceAmount(entity).first == "flammable_gas"	
			or EntityService:GetResourceAmount(entity).first == "mud"	
			or EntityService:GetResourceAmount(entity).first == "morphium"	
			or EntityService:GetResourceAmount(entity).first == "magma"	
			or EntityService:GetResourceAmount(entity).first == "sludge"	
			or EntityService:GetResourceAmount(entity).first == "water"	
			then
                return false
            end
			LogService:Log( " Resource : " .. EntityService:GetResourceAmount(entity).first)
			return true
		end
	});
end

RegisterGlobalEventHandler("PlayerControlledEntityChangeEvent", function(evt)
	
	-----------------------------------------------
	--if evt:GetEvent()~="InitialSpawnEnded" then
	--	return
	--end
	-----------------------------------------------
	LogService:Log("PlayerControlledEntityChangeEvent")
	if CampaignService:GetCurrentCampaignType()=="story" then
		LogService:Log("GetCurrentCampaignType : story")
		return
	end
	-----------------------------------------------
	local database = CampaignService:GetCampaignData()
    if ( database == nil ) then
        LogService:Log("database no")
        return
    end
	local k1="start_give_building_autoexec.lua/" 
	if database:HasInt( k1) then
		LogService:Log(" database has " )
		return
	else
		database:SetInt( k1,1)
		LogService:Log(" database set " )
	end
	-----------------------------------------------
	
	-----------------------------------------------
	--local Entity=MissionService:GetPlayerSpawnPoint()--err
	local Player=MapGenerator:GetInitialSpawnPoint()
	local Position=EntityService:GetPosition(Player)
	--LogService:Log(" Position : x : " .. Position.x .. " , y : " .. Position.y .. " , z : " .. Position.z)
	--EntityService:SpawnEntity( "buildings/main/headquarters_lvl_7", Position.x , Position.y , Position.z , "")--err
	
	local missionDefName = CampaignService:GetCurrentMissionDefName()
	local missionDef = ResourceManager:GetResource("MissionDef", missionDefName)
	local missionDefHelper = reflection_helper( missionDef )
	local search_radius=tonumber(missionDefHelper.max_starting_distance) or 128
	
	local distribution_radius=f_distribution_radius()*2
	
	local tEntity=nil
	local spot=nil
	local Component=nil
	local bp=nil
	
	for _,item in pairs( list ) do
		LogService:Log(" item : " .. item[1] .. " , loop : " .. tostring(item[2]))
		
		--local Blueprint = ResourceManager:GetBlueprint( item[1] )
		--local Component = Blueprint:GetComponent("BuildingDesc")		
		
		Component = EntityService:GetBlueprintComponent(item[1], "BuildingDesc")
		bp=Component:GetField( "bp" ):GetValue()
		--LogService:Log(" bp : " .. bp)
		for i=1,item[2] do 
			spot=FindService:FindEmptySpotInRadius(Player,  search_radius,"","")
			--spot=FindService:FindEmptySpotForBuildingRadius(Player,  search_radius,bp,"","")
			if spot.first then
				Position=spot.second
				--LogService:Log(" Position : x : " .. Position.x .. " , y : " .. Position.y .. " , z : " .. Position.z)			
				tEntity=EntityService:SpawnEntity( item[1], Position.x , Position.y , Position.z , "")
				energy(Position,item[3])
				energy_connector(tEntity,distribution_radius)
				defenseSpawn(Position)
			else
				LogService:Log(" no spot : " .. item[1] )
			end
		end
	end
	-----------------------------------------------	
	chack(Player,search_radius)
	-----------------------------------------------	
	mySpawnEntity(Player, search_radius,distribution_radius, "carbonium", "buildings/resources/carbonium_factory_lvl_3", 16,1)
	mySpawnEntity(Player, search_radius,distribution_radius, "steel", "buildings/resources/steel_factory_lvl_3", 16,1)
	mySpawnEntity(Player, search_radius,distribution_radius, "cobalt", "buildings/resources/rare_element_mine_lvl_3", 4,3) --200,80,48
	mySpawnEntity(Player, search_radius,distribution_radius, "palladium", "buildings/resources/rare_element_mine_lvl_3", 4,3) --200,80,48
	mySpawnEntity(Player, search_radius,distribution_radius, "uranium_ore", "buildings/resources/rare_element_mine_lvl_3", 4,3) --200,80,48
	mySpawnEntity(Player, search_radius,distribution_radius, "titanium", "buildings/resources/rare_element_mine_lvl_3", 4,3) --200,80,48
	mySpawnEntity(Player, search_radius,distribution_radius, "geothermal", "buildings/energy/geothermal_powerplant_lvl_3", 4,0) --200,80,48
	mySpawnEntity(Player, search_radius,distribution_radius, "flammable_gas", "buildings/resources/gas_extractor_lvl_3", 4,0) --200,80,48
	mySpawnEntity(Player, search_radius,distribution_radius, "mud", "buildings/resources/liquid_pump_lvl_3", 4,0) --200,80,48
	mySpawnEntity(Player, search_radius,distribution_radius, "morphium", "buildings/resources/liquid_pump_lvl_3", 4,0) --200,80,48
	mySpawnEntity(Player, search_radius,distribution_radius, "magma", "buildings/resources/liquid_pump_lvl_3", 4,0) --200,80,48
	mySpawnEntity(Player, search_radius,distribution_radius, "sludge", "buildings/resources/liquid_pump_lvl_3", 4,0) --200,80,48
	mySpawnEntity(Player, search_radius,distribution_radius, "water", "buildings/resources/liquid_pump_lvl_3", 4,0) --200,80,48
	--liquid_pump_lvl_3
	-----------------------------------------------
	
	--local Entities=nil
	--local cnt=0
	--for _,item in pairs( list3 ) do
	--	Entities=FindService:FindEntitiesByBlueprint(item)
	--	if ( Entities ~= nil ) then	
	--		LogService:Log( item .. " , " .. tostring(#Entities))
	--	else
	--		LogService:Log( item .. " no ")
	--	end
	--end
	-----------------------------------------------
	--Entities = FindService:FindEntitiesByPredicateInRadius( Entity, search_radius, {
	--	type="",
	--	--signature="ResourceComponent,GridMarkerComponent",
	--	signature="ResourceComponent",
	--	filter = function(entity) 
    --        --local result = EntityService:GetResourceAmount(entity)
    --        --if not PlayerService:IsResourceUnlocked(result.first) then
    --        --    return false
    --        --end
	--		return true
	--	end
	--} );
	--local blueprint_name=""
	--local sEntity=nil
	--if Entities ~=nil and #Entities>0  then
	--	for i=1,16 do
	--		if #Entities>0  then
	--			tEntity=Entities[ math.random( #Entities ) ]
	--			Position=EntityService:GetPosition(tEntity)
	--			blueprint_name=EntityService:GetBlueprintName(tEntity)
	--			if 		string.find(blueprint_name, "resources/resource_carbon") ~=nil then
	--				sEntity=EntityService:SpawnEntity( "buildings/resources/carbonium_factory_lvl_3", Position.x , Position.y , Position.z , "")
	--				tEntity=EntityService:SpawnEntity( "buildings/energy/solar_panels_lvl_3", Position.x , Position.y , Position.z , "")
	--				tEntity=EntityService:SpawnEntity( "buildings/energy/wind_turbine_lvl_3", Position.x , Position.y , Position.z , "")
	--			elseif 	string.find(blueprint_name, "resources/resource_iron") ~=nil then
	--				sEntity=EntityService:SpawnEntity( "buildings/resources/steel_factory_lvl_3", Position.x , Position.y , Position.z , "")
	--				tEntity=EntityService:SpawnEntity( "buildings/energy/solar_panels_lvl_3", Position.x , Position.y , Position.z , "")
	--				tEntity=EntityService:SpawnEntity( "buildings/energy/wind_turbine_lvl_3", Position.x , Position.y , Position.z , "")
	--			elseif 	string.find(blueprint_name, "resources/resource_mud") ~=nil 
	--			then
	--				sEntity=EntityService:SpawnEntity( "buildings/resources/rare_element_mine_lvl_3", Position.x , Position.y , Position.z , "")
	--			elseif 	string.find(blueprint_name, "resources/resource_titanium") ~=nil 
	--			or		string.find(blueprint_name, "resources/resource_cobalt") ~=nil 
	--			or		string.find(blueprint_name, "resources/resource_palladium") ~=nil 
	--			or		string.find(blueprint_name, "resources/resource_uranium_ore") ~=nil 
	--			then
	--				sEntity=EntityService:SpawnEntity( "buildings/resources/rare_element_mine_lvl_3", Position.x , Position.y , Position.z , "")
	--				tEntity=EntityService:SpawnEntity( "buildings/energy/solar_panels_lvl_3", Position.x , Position.y , Position.z , "")
	--				tEntity=EntityService:SpawnEntity( "buildings/energy/wind_turbine_lvl_3", Position.x , Position.y , Position.z , "")
	--				tEntity=EntityService:SpawnEntity( "buildings/energy/solar_panels_lvl_3", Position.x , Position.y , Position.z , "")
	--				tEntity=EntityService:SpawnEntity( "buildings/energy/wind_turbine_lvl_3", Position.x , Position.y , Position.z , "")
	--			else
	--				LogService:Log( " no find : " .. blueprint_name)
	--			end
	--		else
	--			break
	--		end
	--	end
	--else
	--	LogService:Log( " Entities no ")
	--end
	-----------------------------------------------
	--local Component = nil
	--for _,fEntity in pairs( Entities ) do
	--	local blueprint_name=EntityService:GetBlueprintName(fEntity)
	--	LogService:Log(" Blueprint : " .. blueprint_name)
	--	--local Blueprint = ResourceManager:GetBlueprint(blueprint_name)
	--	--for _,componentName in pairs( Blueprint:GetComponentNames() ) do
	--	--	LogService:Log(" * " .. componentName)
	--	--	Component = Blueprint:GetComponent(componentName)
	--	--	Component = EntityService:GetComponent( fEntity ,componentName)
	--		Component = EntityService:GetComponent( fEntity ,"ResourceComponent")
	--		if ( Component ~= nil ) then
	--			for _,FieldName in pairs( Component:GetFieldNames() ) do
	--				LogService:Log("   " .. FieldName .. " : " .. tostring(Component:GetField( FieldName ):GetValue()	))
	--			end
	--		end
	--	--end
	--	
	--end
	-----------------------------------------------
	--for _,item in pairs( list2 ) do
	--	LogService:Log(" item : " .. item[1] .. " , loop : " .. tostring(item[2]))
	--	for i=1,item[2] do 
	--		tEntity=FindEntityByBlueprintInDistance(Entity,item[3],96)
	--		if tEntity~=nil then
	--			Position=EntityService:GetPosition(tEntity)
	--			LogService:Log(" Position : x : " .. Position.x .. " , y : " .. Position.y .. " , z : " .. Position.z)				
	--			EntityService:SpawnEntity( item[1], Position.x , Position.y , Position.z , "")
	--		end
	--	end
	--end

		
end)

-----
--layout: default
--title: ResourceComponent
--has_children: false
--parent: Component
--grand_parent: Game Reflection
-----
--# ResourceComponent
--Description 
--
--## Fields
--
--| Type | Name |
--|:----------|:--------------|
--| [Entity](/riftbreaker-wiki/docs/game-reflection/classes/entity/) | volume_owner |
--| [ResourceAccount](/riftbreaker-wiki/docs/game-reflection/classes/resource_account/) | account |
--| [GameplayResourceDefHolder](/riftbreaker-wiki/docs/game-reflection/components/gameplay_resource_def_holder/) | type |
--| [GameplayResourceDefHolder](/riftbreaker-wiki/docs/game-reflection/components/gameplay_resource_def_holder/) | type_produced |
--| Container< [Entity](/riftbreaker-wiki/docs/game-reflection/classes/entity/) > | indexes_ents |
--| [float](/riftbreaker-wiki/docs/game-reflection/components/float/) | initial_amount |
--| [int](/riftbreaker-wiki/docs/game-reflection/enums/int/) | size |
--| Container< [uint](/riftbreaker-wiki/docs/game-reflection/components/uint/) > | indexes |

