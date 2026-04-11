require("lua/utils/reflection.lua")

local NOW_PER=0
local ADD_PER=10
local k1="escalating_threat_autoexec.lua" 

local function SetHealth(entity)

        local blueprintDatabase = EntityService:GetBlueprintDatabase( ent )
        local max_health = blueprintDatabase:GetInt("max_health")

        HealthService:SetMaxHealth( entity, max_health * (100+NOW_PER)/100 )
end

RegisterGlobalEventHandler("PlayerCreatedEvent", function(evt)
    LogService:Log("PlayerCreatedEvent " )    
    ConsoleService:Write("PlayerCreatedEvent " )    
	local database = CampaignService:GetCampaignData()
    if ( database == nil ) then
        LogService:Log("database no")
        return
    end	
    NOW_PER = database:GetIntOrDefault( k1, NOW_PER)
end)

RegisterGlobalEventHandler("MissionFlowActivatedEvent", function(evt)
    LogService:Log("MissionFlowActivatedEvent " .. evt:GetName( ))    
    ConsoleService:Write("MissionFlowActivatedEvent " .. evt:GetName( ))    
end)

RegisterGlobalEventHandler("MissionFlowDeactivatedEvent", function(evt)
    LogService:Log("MissionFlowDeactivatedEvent " .. evt:GetName( ))    
    ConsoleService:Write("MissionFlowDeactivatedEvent " .. evt:GetName( ))
	-----------------------------------------------
	local database = CampaignService:GetCampaignData()
    if ( database == nil ) then
        LogService:Log("database no")
        return
    end	
    NOW_PER = database:GetIntOrDefault( k1, NOW_PER)+ADD_PER
    database:SetInt( k1, NOW_PER)
    LogService:Log("NOW_PER : " .. NOW_PER)
	-----------------------------------------------
end)
