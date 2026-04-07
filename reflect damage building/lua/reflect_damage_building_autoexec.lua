require("lua/utils/reflection.lua")

local REFLECT_DAMAGE = {
	reflect_type = "damage_ratio", -- health_ratio, damage_ratio, flat_damage
	damage_value = "1",
	-- melee_only = "1",
	damage_types = {
		"default",
		"acid",
		"cryo",
		"energy",
		"explosion",
		"fire",
		"normal",
	},
}

local REFLECT_HIGHLIGHT = {
	submesh_idx = "1",
	glow_factor = "100",
}

local function set_component_field(component, field_name, value)
	if ( component == nil or value == nil ) then
		return
	end

	local ok, field = pcall(function()
		return component:GetField(field_name)
	end)
	if ( ok and field ~= nil ) then
		field:SetValue(tostring(value))
		return
	end

	local helper = reflection_helper(component)
	if ( helper ~= nil ) then
		helper[field_name] = value
	end
end

local function get_or_create_entity_component(entity, component_name)
	local component = EntityService:GetComponent(entity, component_name)
	if ( component ~= nil ) then
		return component
	end

	return EntityService:CreateComponent(entity, component_name)
end

local function get_random_damage_type()
	local damage_type = REFLECT_DAMAGE.damage_types[math.random(#REFLECT_DAMAGE.damage_types)]
	if ( damage_type == "default" ) then
		return nil
	end

	return damage_type
end

local function is_player_owned(entity)
	return EntityService:GetTeam(entity) == EntityService:GetTeam("player")
end

local function apply_reflect_damage(entity)
	if ( entity == nil or entity == INVALID_ID ) then
		return
	end

	if ( not EntityService:IsAlive(entity) ) then
		return
	end

	if ( not is_player_owned(entity) ) then
		return
	end

	local reflect_damage_component = get_or_create_entity_component(entity, "ReflectDamageComponent")
	if ( reflect_damage_component ~= nil ) then
		set_component_field(reflect_damage_component, "reflect_type", REFLECT_DAMAGE.reflect_type)
		set_component_field(reflect_damage_component, "melee_only", REFLECT_DAMAGE.melee_only)
		set_component_field(reflect_damage_component, "damage_value", REFLECT_DAMAGE.damage_value)
		set_component_field(reflect_damage_component, "damage_type", get_random_damage_type())
	else
		LogService:Log("ReflectDamageComponent create fail : " .. tostring(entity))
	end

	local reflect_highlight_component = get_or_create_entity_component(entity, "ReflectHighlightComponent")
	if ( reflect_highlight_component ~= nil ) then
		set_component_field(reflect_highlight_component, "submesh_idx", REFLECT_HIGHLIGHT.submesh_idx)
		set_component_field(reflect_highlight_component, "glow_factor", REFLECT_HIGHLIGHT.glow_factor)
	else
		LogService:Log("ReflectHighlightComponent create fail : " .. tostring(entity))
	end
end

RegisterGlobalEventHandler("StartBuildingEvent", function(evt)
	local entity = evt:GetEntity()
	apply_reflect_damage(entity)
	ConsoleService:Write("StartBuildingEvent : " .. tostring(entity))
	LogService:Log("StartBuildingEvent : " .. tostring(entity))
end)

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
	ConsoleService:Write("FindEntitiesByType building : " .. tostring(#entities))
	LogService:Log("FindEntitiesByType building : " .. tostring(#entities))
	for _,entity in pairs( entities ) do
		apply_reflect_damage(entity)
	end
end)
