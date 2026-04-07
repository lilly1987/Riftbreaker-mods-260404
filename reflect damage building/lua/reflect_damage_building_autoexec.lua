
RegisterGlobalEventHandler("StartBuildingEvent", function(evt)
	-- LogService:Log("StartBuildingEvent : " .. tostring(evt:GetEntity() ))
	-- local currentDifficultyName = DifficultyService:GetCurrentDifficultyName() 
	local entity=evt:GetEntity() 
	-- HealthService:SetMaxHealth( entity, HealthService:GetMaxHealth( entity) * 100 )
end)

local function get_or_create_component(blueprint, component_name)
	local component = blueprint:GetComponent(component_name)
	if ( component ~= nil ) then
		return component
	end

	local ok, created = pcall(function()
		return blueprint:CreateComponent(component_name)
	end)
	if ( ok ) then
		component = blueprint:GetComponent(component_name)
		if ( component ~= nil ) then
			return component
		end
		if ( created ~= nil and created ~= true ) then
			return created
		end
	end

	ok, created = pcall(function()
		return blueprint:AddComponent(component_name)
	end)
	if ( ok ) then
		component = blueprint:GetComponent(component_name)
		if ( component ~= nil ) then
			return component
		end
		if ( created ~= nil and created ~= true ) then
			return created
		end
	end

	return nil
end

local function set_component_field(component, field_name, value)
	if ( component == nil ) then
		return
	end

	local field = component:GetField(field_name)
	if ( field ~= nil ) then
		field:SetValue(tostring(value))
	end
end

RegisterGlobalEventHandler("MissionFlowDeactivatedEvent", function(evt)
	-----------------------------------------------
	local database = CampaignService:GetCampaignData()
    if ( database == nil ) then
        LogService:Log("database no")
        return
    end
	local k1="reflect_damage_building_autoexec.lua/" 
	if database:HasInt( k1) then
		LogService:Log(" database has " )
		return
	else
		database:SetInt( k1,1)
		LogService:Log(" database set " )
	end
	-----------------------------------------------
	local entities = FindService:FindEntitiesByType( "building" )
	for _,entity in pairs( entities ) do
		-- HealthService:SetMaxHealth( entity, HealthService:GetMaxHealth( entity) * 100 )
	end
end)

local setup=function(blueprint_name)
	LogService:Log(blueprint_name)
	
	local blueprint = ResourceManager:GetBlueprint(blueprint_name)
	if ( blueprint == nil ) then
		LogService:Log(" blueprint no : " .. blueprint_name)
		return
	end
	
	local reflect_damage_component = get_or_create_component(blueprint, "ReflectDamageComponent")
	if ( reflect_damage_component == nil ) then
		LogService:Log(" ReflectDamageComponent create fail : " .. blueprint_name)
		return
	end
	
	set_component_field(reflect_damage_component, "reflect_type", "damage_ratio") -- health_ratio, damage_ratio, flat_damage
	-- set_component_field(reflect_damage_component, "melee_only", "1")
	set_component_field(reflect_damage_component, "damage_value", "1")
	-- set_component_field(reflect_damage_component, "damage_type", "energy")
	
	local reflect_highlight_component = get_or_create_component(blueprint, "ReflectHighlightComponent")
	if ( reflect_highlight_component ~= nil ) then
		set_component_field(reflect_highlight_component, "submesh_idx", "1")
		set_component_field(reflect_highlight_component, "glow_factor", "100")
	else
		LogService:Log(" ReflectHighlightComponent create fail : " .. blueprint_name)
	end
	
	--local buildingComponent = blueprint:GetComponent("BuildingComponent")		
	--local type = buildingComponent:GetField("type"):GetValue())
	--LogService:Log(" type : " .. type)
	
	-- local TypeComponent = blueprint:GetComponent("TypeComponent")		
	-- local type = TypeComponent:GetField("type"):GetValue()
	-- LogService:Log(" type : " .. type)
	
	-- local max_health=0
	-- local health=0
	
	-- local HealthDesc = blueprint:GetComponent("HealthDesc")	
	-- if ( HealthDesc == nil ) then
	-- 	LogService:Log(" HealthDesc no ")
	-- else
	-- 	max_health = HealthDesc:GetField("max_health"):GetValue()
	-- 	LogService:Log(" max_health : " .. max_health)
	-- end
	
	-- local HealthComponent = blueprint:GetComponent("HealthComponent")	
	-- if ( HealthComponent == nil ) then
	-- 	LogService:Log(" HealthComponent no ")
	-- else
	-- 	max_health = HealthComponent:GetField("max_health"):GetValue()
	-- 	LogService:Log(" max_health : " .. max_health)
	-- end
end


RegisterGlobalEventHandler("PlayerInitializedEvent", function(evt)
	setup()
end)