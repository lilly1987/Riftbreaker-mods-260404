LogService:Log("start make gate, trap")

local list={
"buildings/defense/trap_acid"    ,
"buildings/defense/trap_energy"  ,
"buildings/defense/trap_fire"    ,
"buildings/defense/trap_physical",
"buildings/defense/trap_cryo"    ,
"buildings/defense/trap_area"    ,
}

RegisterGlobalEventHandler("PlayerControlledEntityChangeEvent", function(evt)
	LogService:Log("PlayerControlledEntityChangeEvent ST")
	-----------------------------------------------
	--local my="player/character_base"
	--local database = EntityService:GetBlueprintDatabase( my )
	local database = EntityService:GetDatabase( evt:GetControlledEntity() )
    if ( database == nil ) then
        LogService:Log("database no" )
        return
    end
	local k="start_make_gate_autoexec.lua/" 
	if database:HasInt( k) then
		LogService:Log(" database has " )
		return
	else
		database:SetInt( k,1)
		LogService:Log(" database set " )
	end
	-----------------------------------------------
	--ConsoleService:ExecuteCommand("r_show_map_info 1")
	-----------------------------------------------
    local playable_min = MissionService:GetPlayableRegionMin();
    local playable_max = MissionService:GetPlayableRegionMax();
	local margin = tonumber(ConsoleService:GetConfig("map_non_playable_margin")) * 2
	LogService:Log(" playable_max : " .. playable_max.x .. " , " .. playable_max.z)
	LogService:Log(" playable_min : " .. playable_min.x .. " , " .. playable_min.z)
	LogService:Log(" margin : " .. margin)
	
	local Entity=nil
	
	local xmax=playable_max.x - margin - 2
	local xmin=playable_min.x + margin + 2
	local zmax=playable_max.z - margin + 2
	local zmin=playable_min.z + margin - 2
	
	local n=playable_max.x - margin + 2
	local s=playable_min.x + margin - 2
	local w=playable_min.z + margin - 2
	local e=playable_max.z - margin + 2

	for z = zmin , zmax , 4 do
		--북
		Entity=EntityService:SpawnEntity("buildings/defense/wall_gate_energy_lvl_3", n , 0 , z , "")	
		Entity=EntityService:SpawnEntity("buildings/defense/wall_gate_energy_lvl_3", s , 0 , z , "")	
		EntityService:Rotate(Entity,0,1,0,180) -- 시계 반대 방향
	end                                                                                                                
	
	for x = xmin , xmax , 4 do
		--서
		Entity=EntityService:SpawnEntity("buildings/defense/wall_gate_energy_lvl_3", x , 0 , w , "")
		EntityService:Rotate(Entity,0,1,0,90)
		Entity=EntityService:SpawnEntity("buildings/defense/wall_gate_energy_lvl_3", x , 0 , e , "")
		EntityService:Rotate(Entity,0,1,0,270)
	end

	for z = zmin - 4 , zmax + 4 , 4 do
		--북
		Entity=EntityService:SpawnEntity( list[ math.random( #list ) ] , n+4 , 0 , z , "")	
		Entity=EntityService:SpawnEntity( list[ math.random( #list ) ] , s-4 , 0 , z , "")	
	end                                                                                                                
	
	for x = xmin - 4 , xmax + 4 , 4 do
		--서
		Entity=EntityService:SpawnEntity( list[ math.random( #list ) ] , x , 0 , w-4 , "")
		Entity=EntityService:SpawnEntity( list[ math.random( #list ) ] , x , 0 , e+4 , "")
	end

	LogService:Log("PlayerControlledEntityChangeEvent ED")
end)