require("lua/utils/reflection.lua")

local COMPONENT_NAME_CANDIDATES = {
	"BoundsComponent",
	"BuildInfoComponent",
	"BuildingComponent",
	"BuildingDesc",
	"BuildingSelectorComponent",
	"BurningComponent",
	"EntityModComponent",
	"EffectReferenceComponent",
	"EntityStatComponent",
	"GameplayResourceLayerComponent",
	"GridCullerComponent",
	"GuiComponent",
	"HealthComponent",
	"InteractiveComponent",
	"InventoryItemComponent",
	"InventoryItemRuntimeDataComponent",
	"LifeTimeComponent",
	"LootComponent",
	"MeshComponent",
	"NavMeshMovementComponent",
	"ParentComponent",
	"PhysicsComponent",
	"PlayerReferenceComponent",
	"ResourceComponent",
	"ResourceConverterComponent",
	"ResurrectUnitComponent",
	"RiftPointComponent",
	"SelectableComponent",
	"SkillUnitComponent",
	"StealthComponent",
	"TurretComponent",
	"TurretDesc",
	"UnitsSpawnerComponent",
	"VegetationComponent",
	"VegetationLifecycleEnablerComponent",
	"WeaponModComponent",
	"WorldBlockerLayerComponent",
	"WreckTeamComponent",
}

local function DebugLog(message)
	LogService:Log(message)
	-- ConsoleService:Write(message)
end

local function SafeHasComponent(entity, componentName)
	local ok, result = pcall(function()
		return EntityService:HasComponent(entity, componentName)
	end)

	return ok and result == true
end

local function DumpEntityComponents(entity)
	if entity == nil or entity == INVALID_ID or not EntityService:IsAlive(entity) then
		return
	end

	local blueprintName = EntityService:GetBlueprintName(entity)
	if blueprintName == nil or blueprintName == "" then
		return
	end
	if not  blueprintName:find("items/upgrades/") and not blueprintName:find("items/weapons/") then
		return
	end

	LogService:Log( blueprintName  )
	-- local found = {}
	for _, componentName in ipairs(COMPONENT_NAME_CANDIDATES) do
		if SafeHasComponent(entity, componentName) then
			-- table.insert(found, componentName)
			local refl_Component = reflection_helper( EntityService:GetComponent(entity, componentName))
			LogService:Log( componentName .. " : " ..tostring(refl_Component)  )
		end
	end

	-- if #found == 0 then
	-- 	-- DebugLog("[entity_components] item=" .. tostring(blueprintName) .. " components=none_from_candidate_list")
	-- 	return
	-- end

	-- DebugLog("[entity_components] item=" .. tostring(blueprintName) .. " components=" .. table.concat(found, ","))
end

-- RegisterGlobalEventHandler("PickedUpItemEvent", function(evt)
-- 	DumpEntityComponents(evt:GetEntity())
-- end)
