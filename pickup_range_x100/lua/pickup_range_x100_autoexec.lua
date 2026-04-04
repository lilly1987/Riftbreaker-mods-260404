-- pickup_range_x100_autoexec.lua
RegisterGlobalEventHandler("PlayerControlledEntityChangeEvent", function(evt)
	local controlledEntity=evt:GetControlledEntity()
    local database = EntityService:GetDatabase( controlledEntity )			
    if ( database == nil ) then
        LogService:Log(" no database")
        return
	else
		LogService:Log(" has database")
		
		local k="pickup_range_x100_autoexec.lua"
		if database:HasInt( k) then
			LogService:Log(" Already has : " .. k)
			return
		else
			database:SetInt( k,1)
			LogService:Log(" database set : " .. k)
		end
    end
	
	local playerId=evt:GetPlayerId()
	LogService:Log(" playerId : " .. tostring(playerId)) 
	PlayerService:SetPickupRange(playerId,PlayerService:GetPickupRange(playerId)*100)
end)