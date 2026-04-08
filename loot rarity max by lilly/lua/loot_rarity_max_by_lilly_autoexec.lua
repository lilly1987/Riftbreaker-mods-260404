LogService:Log("loot rarity max by lilly")
ConsoleService:Write("loot rarity max by lilly: weapon mod min values use max values")

local g_weapon_mod_min_value_patched = false
local g_weapon_item_stats_patched = false
local g_entity_mods_patched = false
local RANDOM_WEAPON_MOD_COUNT = 3

local function HasPrefix(value, prefix)
	return string.sub(value, 1, string.len(prefix)) == prefix
end

local function HasSuffix(value, suffix)
	return suffix == "" or string.sub(value, -string.len(suffix)) == suffix
end

local function AppendUniqueItems(target, items)
	local seen = {}

	for _, item in ipairs(target) do
		seen[item] = true
	end

	for _, item in ipairs(items or {}) do
		if not seen[item] then
			table.insert(target, item)
			seen[item] = true
		end
	end
end

local function GetMapValueField(container, key, createMissing)
	if container == nil then
		return nil
	end

	for i = 0, container:GetItemCount() - 1 do
		local item = container:GetItem(i)
		local keyField = item:GetField("key")
		if keyField ~= nil and keyField:GetValue() == key then
			return item:GetField("value")
		end
	end

	if createMissing then
		local item = container:ReserveItem()
		item:GetField("key"):SetValue(tostring(key))
		container:InsertItem(item)
		return item:GetField("value")
	end

	return nil
end

local function FormatPercentModValue(multiplierText)
	local multiplier = tonumber(multiplierText)
	if multiplier == nil then
		return multiplierText
	end

	return string.format("%.3f%%", (multiplier - 1.0) * 100.0)
end

local function PatchEntityModDesc(desc)
	local entityModsField = desc:GetField("entity_mods")
	local randomMaxValuesField = desc:GetField("random_max_values")
	if entityModsField == nil or randomMaxValuesField == nil then
		return 0
	end

	local entityMods = entityModsField:ToContainer()
	local randomMaxValues = randomMaxValuesField:ToContainer()
	if entityMods == nil or randomMaxValues == nil then
		return 0
	end

	local patchedCount = 0
	for i = 0, randomMaxValues:GetItemCount() - 1 do
		local item = randomMaxValues:GetItem(i)
		local keyField = item:GetField("key")
		local valueField = item:GetField("value")

		if keyField ~= nil and valueField ~= nil then
			local key = keyField:GetValue()
			local maxValue = valueField:GetValue()
			local entityModValue = GetMapValueField(entityMods, key, true)

			if entityModValue ~= nil then
				local currentValue = entityModValue:GetValue()
				if currentValue ~= nil and HasSuffix(currentValue, "%") then
					entityModValue:SetValue(FormatPercentModValue(maxValue))
				else
					entityModValue:SetValue(maxValue)
				end
				patchedCount = patchedCount + 1
			end
		end
	end

	local modFlagsField = desc:GetField("mod_flags")
	if modFlagsField ~= nil then
		local modFlags = modFlagsField:ToContainer()
		if modFlags ~= nil then
			for i = modFlags:GetItemCount() - 1, 0, -1 do
				modFlags:EraseItem(i)
			end
		end
	end

	return patchedCount
end

local function PatchWeaponModMinValues()
	if g_weapon_mod_min_value_patched then
		return
	end

	local weaponMods = ItemService:GetAllItemsBlueprintsByType("weapon_mod") or {}
	if #weaponMods == 0 then
		LogService:Log("loot rarity max by lilly: weapon mod blueprints not ready")
		return
	end

	g_weapon_mod_min_value_patched = true
	local patchedCount = 0

	for _, blueprintName in ipairs(weaponMods) do
		local blueprint = ResourceManager:GetBlueprint(blueprintName)
		if blueprint ~= nil then
			local desc = blueprint:GetComponent("WeaponModDesc")
			if desc ~= nil then
				local maxValue = desc:GetField("max_value")
				local minValue = desc:GetField("min_value")

				if maxValue ~= nil and minValue ~= nil then
					minValue:SetValue(maxValue:GetValue())
					patchedCount = patchedCount + 1
				end
			end
		end
	end

	LogService:Log("loot rarity max by lilly: patched weapon mod min_value count " .. tostring(patchedCount))
	ConsoleService:Write("loot rarity max by lilly: patched weapon mod min_value count " .. tostring(patchedCount))
end

local function CollectWeaponItemBlueprints()
	local itemTypes = {
		"weapon",
		"melee_weapon",
		"range_weapon",
		"support_mech_upgrade",
		"defensive_mech_upgrade",
	}
	local items = {}

	for _, itemType in ipairs(itemTypes) do
		local blueprints = ItemService:GetAllItemsBlueprintsByType(itemType) or {}
		local matching = {}

		for _, blueprintName in ipairs(blueprints) do
			if HasPrefix(blueprintName, "items/weapons/") then
				table.insert(matching, blueprintName)
			end
		end

		AppendUniqueItems(items, matching)
	end

	return items
end

local function PatchWeaponItemStatMinValues()
	if g_weapon_item_stats_patched then
		return
	end

	local weaponItems = CollectWeaponItemBlueprints()
	if #weaponItems == 0 then
		LogService:Log("loot rarity max by lilly: weapon item blueprints not ready")
		return
	end

	g_weapon_item_stats_patched = true
	local patchedCount = 0

	for _, blueprintName in ipairs(weaponItems) do
		local blueprint = ResourceManager:GetBlueprint(blueprintName)
		if blueprint ~= nil then
			local desc = blueprint:GetComponent("WeaponItemDesc")
			if desc ~= nil then
				local statDefVec = desc:GetField("stat_def_vec")
				if statDefVec ~= nil then
					local statDefs = statDefVec:ToContainer()
					if statDefs ~= nil then
						for i = 0, statDefs:GetItemCount() - 1 do
							local statDef = statDefs:GetItem(i)
							local maxValue = statDef:GetField("max_value")
							local minValue = statDef:GetField("min_value")

							if maxValue ~= nil and minValue ~= nil then
								minValue:SetValue(maxValue:GetValue())
								patchedCount = patchedCount + 1
							end
						end
					end
				end
			end
		end
	end

	LogService:Log("loot rarity max by lilly: patched weapon item stat min_value count " .. tostring(patchedCount))
	ConsoleService:Write("loot rarity max by lilly: patched weapon item stat min_value count " .. tostring(patchedCount))
end

local function PatchEntityModMaxValues()
	if g_entity_mods_patched then
		return
	end

	local upgradeItems = ItemService:GetAllItemsBlueprintsByType("upgrade") or {}
	if #upgradeItems == 0 then
		LogService:Log("loot rarity max by lilly: entity mod blueprints not ready")
		return
	end

	g_entity_mods_patched = true
	local patchedCount = 0
	local blueprintCount = 0

	for _, blueprintName in ipairs(upgradeItems) do
		local blueprint = ResourceManager:GetBlueprint(blueprintName)
		if blueprint ~= nil then
			local desc = blueprint:GetComponent("EntityModDesc")
			if desc ~= nil then
				local count = PatchEntityModDesc(desc)
				if count > 0 then
					blueprintCount = blueprintCount + 1
					patchedCount = patchedCount + count
				end
			end
		end
	end

	LogService:Log("loot rarity max by lilly: patched entity mod max value count " .. tostring(patchedCount) .. " in " .. tostring(blueprintCount) .. " blueprints")
	ConsoleService:Write("loot rarity max by lilly: patched entity mod max value count " .. tostring(patchedCount))
end

local function CollectWeaponModBlueprints()
	local weaponMods = ItemService:GetAllItemsBlueprintsByType("weapon_mod") or {}
	local items = {}

	for _, blueprintName in ipairs(weaponMods) do
		local blueprint = ResourceManager:GetBlueprint(blueprintName)
		if blueprint ~= nil and blueprint:GetComponent("WeaponModDesc") ~= nil then
			table.insert(items, blueprintName)
		end
	end

	return items
end

local function GiveRandomWeaponMods(playerId, count)
	local campaignData = CampaignService:GetCampaignData()
	if campaignData == nil then
		LogService:Log("loot rarity max by lilly: campaign data not ready")
		return
	end

	local key = "loot_rarity_max_by_lilly_autoexec.lua/random_weapon_mods/" .. tostring(playerId)
	if campaignData:HasInt(key) then
		return
	end

	local weaponMods = CollectWeaponModBlueprints()
	if #weaponMods == 0 then
		LogService:Log("loot rarity max by lilly: random weapon mod blueprints not ready")
		return
	end

	PlayerService:UnlockLoot(playerId, "weapon_mod")

	local addedCount = 0
	for i = 1, count do
		if #weaponMods == 0 then
			break
		end

		local randomIndex = RandInt(1, #weaponMods)
		local blueprintName = weaponMods[randomIndex]
		table.remove(weaponMods, randomIndex)

		PlayerService:AddItemToInventory(playerId, blueprintName)
		addedCount = addedCount + 1
		LogService:Log("loot rarity max by lilly: added random weapon mod " .. tostring(blueprintName))
	end

	campaignData:SetInt(key, 1)
	LogService:Log("loot rarity max by lilly: added random weapon mod count " .. tostring(addedCount))
	ConsoleService:Write("loot rarity max by lilly: added random weapon mod count " .. tostring(addedCount))
end

RegisterGlobalEventHandler("PlayerInitializedEvent", function(evt)
	PatchWeaponModMinValues()
	PatchWeaponItemStatMinValues()
	PatchEntityModMaxValues()
end)

RegisterGlobalEventHandler("PlayerControlledEntityChangeEvent", function(evt)
	PatchWeaponModMinValues()
	PatchWeaponItemStatMinValues()
	PatchEntityModMaxValues()
	--GiveRandomWeaponMods(evt:GetPlayerId(), RANDOM_WEAPON_MOD_COUNT)
end)
