LogService:Log("loot rarity max by lilly")
ConsoleService:Write("loot rarity max by lilly: weapon mod min values use max values")

local g_weapon_mod_min_value_patched = false
local RANDOM_WEAPON_MOD_COUNT = 3

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
end)

RegisterGlobalEventHandler("PlayerControlledEntityChangeEvent", function(evt)
	PatchWeaponModMinValues()
	GiveRandomWeaponMods(evt:GetPlayerId(), RANDOM_WEAPON_MOD_COUNT)
end)
