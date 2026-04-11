-- minimap clicked teleport
LogService:Log("MinimapClickedEvent Reg")
-----
--layout: default
--title: MinimapClickedEvent
--nav_order: 1
--has_children: true
--parent: Lua services
-----
--### GetEntity
-- * (): [Entity const&](riftbreaker-wiki/docs/reflection/Entity const&)
--  
--### GetMinimapType
-- * (): [enum MinimapType const&](riftbreaker-wiki/docs/reflection/enum MinimapType const&)
--  
--### GetWorldPosition
-- * (): [Math::Vector3<float> const&](riftbreaker-wiki/docs/reflection/Math::Vector3<float> const&)
RegisterGlobalEventHandler("MinimapClickedEvent", function(evt)
	-- LogService:Log("MinimapClickedEvent ST")
	
    -- LogService:Log("Entity : " .. tostring(evt:GetEntity()))-- player_respawner.lua INVALID_ID==PlayerSpawnRequest.SpawnPoint
	
	local MinimapType=evt:GetMinimapType() -- 0,1
	if ( MinimapType ~= 1 ) then
		return
	end
	
	local WorldPosition=evt:GetWorldPosition()
	WorldPosition.y=WorldPosition.y+4
	-- LogService:Log("WorldPosition : x : " .. WorldPosition.x .. " , y : " .. WorldPosition.y .. " , z : " .. WorldPosition.z)
	
	--local controlledEntity=FindService:FindEntityByBlueprint("player/character")
	--LogService:Log(" controlledEntity : " .. (controlledEntity))
    local player = PlayerService:GetLeadingPlayer();
	-- LogService:Log(" player : " .. player)
    local mech = PlayerService:GetPlayerControlledEnt(player)
	-- LogService:Log(" mech : " .. mech)

    -- void TeleportPlayer( Exor::Entity ent, Exor::Vector3 pos, float disappera, float wait, float appear );
	PlayerService:TeleportPlayer( mech, WorldPosition , 0.125, 0.0625, 0.125 )
    
    -- LogService:Log("MinimapClickedEvent ED")
end)
