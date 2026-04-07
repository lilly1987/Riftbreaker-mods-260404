RegisterGlobalEventHandler("PlayerControlledEntityChangeEvent", function(evt)
    local radarPulseEffect = EntityService:SpawnEntity( "items/consumables/radar_pulse", evt:GetControlledEntity(), "")

	local radarRevealer = EntityService:GetComponent(radarPulseEffect, "FogOfWarRevealerComponent" )
	if ( radarRevealer == nil ) then
		Assert( false, "ERROR: No fog of war revealer component:" )
	end
	
	local helper = reflection_helper( radarRevealer ) 
	
	helper.radius = 256 --self.data:GetFloatOrDefault( "radius", 100 ) 
	local lifeTime = 60 --self.data:GetFloatOrDefault("life_time", 10 )
	EntityService:CreateOrSetLifetime( radarPulseEffect, lifeTime, "normal" )
end)