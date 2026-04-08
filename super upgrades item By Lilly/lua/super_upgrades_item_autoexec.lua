--RegisterGlobalEventHandler("PlayerCreatedEvent", function(evt)
--	LogService:Log(" PlayerCreatedEvent ".. tostring(evt:GetPlayerId()) )
--end)
LogService:Log("super upgrades item By Lilly"  )
ConsoleService:Write("super upgrades item By Lilly 2604041259"  )

local function HasPrefix(value, prefix)
	return string.sub(value, 1, string.len(prefix)) == prefix
end

local function HasSuffix(value, suffix)
	return suffix == "" or string.sub(value, -string.len(suffix)) == suffix
end

local function ContainsText(value, text)
	return text ~= nil and string.find(value, text, 1, true) ~= nil
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

local function CollectExtremeItems(specs, extraItems)
	local items = {}
	
	for _, spec in ipairs(specs or {}) do
		local blueprints = ItemService:GetAllItemsBlueprintsByType(spec.item_type) or {}
		
		for _, blueprint in ipairs(blueprints) do
			if (spec.prefix == nil or HasPrefix(blueprint, spec.prefix))
			and (spec.suffix == nil or HasSuffix(blueprint, spec.suffix))
			and (spec.contains == nil or ContainsText(blueprint, spec.contains))
			and (spec.exclude_contains == nil or not ContainsText(blueprint, spec.exclude_contains)) then
				table.insert(items, blueprint)
			end
		end
	end
	
	AppendUniqueItems(items, extraItems)
	-- table.sort(items)
	return items
end

local function DropEquippedUpgradeItems(player_id)
	local upgradeSlots = {
		"UPGRADE_1",
		"UPGRADE_2",
		"UPGRADE_3",
		"UPGRADE_4",
	}
	local mech = PlayerService:GetPlayerControlledEnt(player_id)
	if mech == nil or mech == INVALID_ID then
		LogService:Log("DropEquippedUpgradeItems: mech not found for player " .. tostring(player_id))
		ConsoleService:Write("DropEquippedUpgradeItems: mech not found for player " .. tostring(player_id))
		return
	end

	for _, slot in ipairs(upgradeSlots) do
		local item = ItemService:GetEquippedItem(mech, slot)
		if item ~= nil and item ~= INVALID_ID then
			LogService:Log("DropEquippedUpgradeItems: removing " .. tostring(slot) .. " item " .. tostring(item))
			ConsoleService:Write("DropEquippedUpgradeItems: removing " .. tostring(slot) .. " item " .. tostring(item))
			QueueEvent("UnequipItemRequest", mech, item, slot)
			PlayerService:DropItem(item, mech, mech)
		end
	end
end

-- RegisterGlobalEventHandler("PlayerInitializedEvent", function(evt)
RegisterGlobalEventHandler("PlayerControlledEntityChangeEvent", function(evt)
	LogService:Log(" run : " .. tostring(evt:GetPlayerId()) )
	
	-----------------------------------------------
	local database1 = CampaignService:GetCampaignData()
    if ( database1 == nil ) then
        LogService:Log("NOT EXISTS database ")
        return
    end
	local k1="super_upgrades_item_autoexec.lua/" 
	if database1:HasInt( k1) then
		LogService:Log(" Already applied " )
		return
	else
		database1:SetInt( k1,1)
		LogService:Log(" database set " )
	end
	-----------------------------------------------
	
	local weapon = CollectExtremeItems(
		{
			-- { item_type = "weapon", prefix = "items/weapons/", suffix = "_extreme_item" },
			{ item_type = "melee_weapon", prefix = "items/weapons/", suffix = "_extreme_item" },
			{ item_type = "range_weapon", prefix = "items/weapons/", suffix = "_extreme_item" },
			{ item_type = "support_mech_upgrade", prefix = "items/weapons/", suffix = "_extreme_item" },
			{ item_type = "defensive_mech_upgrade", prefix = "items/weapons/", suffix = "_extreme_item" }
		},
		{
			"items/weapons/auto_blaster_extreme_item",
			"items/weapons/auto_atom_bomb_extreme_item",
			"items/weapons/auto_heavy_plasma_extreme_item",
			"items/weapons/auto_bouncing_blades_extreme_item",
			"items/weapons/auto_burst_rifle_extreme_item",
			"items/weapons/auto_railgun_extreme_item",
			"items/weapons/auto_charged_bomb_extreme_item",
			"items/weapons/auto_mortar_extreme_item",
			"items/weapons/auto_lava_gun_extreme_item",
			"items/weapons/auto_rocket_launcher_extreme_item",
			"items/weapons/auto_shotgun_extreme_item",
			"items/weapons/auto_sniper_rifle_extreme_item",
			"items/weapons/auto_semi_auto_extreme_item"
		}
	)
	LogService:Log(" extreme item count : " .. tostring(#weapon))	

	local upgrade = CollectExtremeItems(
		{
			{ item_type = "upgrade", prefix = "items/upgrades/", suffix = "_extreme_item" },
		}
	)
	LogService:Log(" extreme upgrade count : " .. tostring(#upgrade))
	local etcs = CollectExtremeItems(
		{
			{ item_type = "misc", prefix = "items/", suffix = "_extreme_item" },
			{ item_type = "shield", prefix = "items/", suffix = "_extreme_item" },
			{ item_type = "equipment", prefix = "items/", suffix = "_extreme_item" },
			{ item_type = "movement_skill", prefix = "items/", suffix = "_extreme_item" },
			{ item_type = "invisible_skill", prefix = "items/", suffix = "_extreme_item" },
			{ item_type = "skill", prefix = "items/", suffix = "_extreme_item" },
			{ item_type = "dash_skill", prefix = "items/", suffix = "_extreme_item" },
			{ item_type = "consumable", prefix = "items/", suffix = "_extreme_item" },
			{ item_type = "passive", prefix = "items/", suffix = "_extreme_item" },
			{ item_type = "upgrade_parts", prefix = "items/", suffix = "_extreme_item" },
			{ item_type = "interactive", prefix = "items/", suffix = "_extreme_item" },
			{ item_type = "saplings", prefix = "items/", suffix = "_extreme_item" },
		}
	)
	LogService:Log(" extreme etcs count : " .. tostring(#etcs))

	local weapon_mod = CollectExtremeItems({
		{
			item_type = "weapon_mod",
			prefix = "items/loot/weapon_mods/mod_",
			suffix = "_extreme_item"
		}
	})
	LogService:Log(" extreme weapon mod count : " .. tostring(#weapon_mod))

	
	local player_id = evt:GetPlayerId()
	--local players = PlayerService:GetAllPlayers()
	--for player_id in Iter(players) do
		--LogService:Log(" player_id : " .. tostring(player_id))

		-- GetAllEquippedItemsInSlot(PlayerService&,custom [class Exor::UtfString<char,class Exor::utf_traits<char>,class Exor::StlAllocatorProxy<char> >] const&,unsigned int)
		local LEFT_HAND=PlayerService:GetAllEquippedItemsInSlot("LEFT_HAND",player_id)
		local RIGHT_HAND=PlayerService:GetAllEquippedItemsInSlot("RIGHT_HAND",player_id)
		for _, item in ipairs(LEFT_HAND) do
			-- 진입 안함
			LogService:Log(" currently equipped LEFT_HAND item : " .. tostring(item))
			PlayerService:DropItem( item, owner, owner )
			EntityService:RemoveEntity(item)
		end
		
		for _, item in ipairs(RIGHT_HAND) do
			LogService:Log(" currently equipped RIGHT_HAND item : " .. tostring(item))
			PlayerService:DropItem( item, owner, owner )
			EntityService:RemoveEntity(item)
		end

		-- local LEFT_HAND=nil
		-- local RIGHT_HAND=nil
		local subslotCount = 0
		local LEFT_HAND_ck = true
		local RIGHT_HAND_ck = true
		for _, item in ipairs(weapon) do			
			LEFT_HAND=PlayerService:AddItemToInventory(player_id, item)
			RIGHT_HAND=PlayerService:AddItemToInventory(player_id, item)
			
			if LEFT_HAND_ck and not PlayerService:TryEquipItemInSlot( player_id, LEFT_HAND, "LEFT_HAND", subslotCount) 
			then
				-- LEFT_HAND_ck = false
				ConsoleService:Write("Failed to equip " .. tostring(item) .. " in LEFT_HAND for player " .. tostring(player_id) .. " subslot " .. tostring(subslotCount) )
			end
			if RIGHT_HAND_ck and not PlayerService:TryEquipItemInSlot( player_id, RIGHT_HAND, "RIGHT_HAND", subslotCount) 
			then
				-- RIGHT_HAND_ck = false
				-- 여기 진입 안들어옴
				ConsoleService:Write("Failed to equip " .. tostring(item) .. " in RIGHT_HAND for player " .. tostring(player_id) .. " subslot " .. tostring(subslotCount) )
			end
			if subslotCount < 6 then
				subslotCount = subslotCount + 1
			else
				subslotCount = 0
				LEFT_HAND_ck = false
				RIGHT_HAND_ck = false
			end
		end
		-- if not equipped, keep in inventory

		-- DropEquippedUpgradeItems(player_id)
		local item_entity=PlayerService:GetAllEquippedItemsInSlot("UPGRADE_1",player_id)
		for _, item in ipairs(item_entity) do
			LogService:Log(" currently equipped UPGRADE_1 item : " .. tostring(item))
			PlayerService:DropItem( item, owner, owner )
			EntityService:RemoveEntity(item)
		end

		local item_entity = nil
		item_entity = PlayerService:AddItemToInventory(player_id, "items/upgrades/lilly_extreme_item")
		PlayerService:EquipItemInSlot(player_id, item_entity, "UPGRADE_4")

		item_entity = PlayerService:AddItemToInventory(player_id, "items/upgrades/scanner_equipment_extreme_item")
		PlayerService:EquipItemInSlot(player_id, item_entity, "UPGRADE_2")
		
		item_entity = PlayerService:AddItemToInventory(player_id, "items/upgrades/detector_equipment_extreme_item")
		PlayerService:EquipItemInSlot(player_id, item_entity, "UPGRADE_3")

		local equippedCount = 5
		for _, item in ipairs(upgrade) do			
			local item_entity = PlayerService:AddItemToInventory(player_id, item)
			if item == "items/upgrades/lilly_extreme_item" 
			or item == "items/upgrades/scanner_equipment_extreme_item" 
			or item == "items/upgrades/detector_equipment_extreme_item" 
			then
				-- already equipped above
			else
				if PlayerService:HasEmptyEquipmentSlots(player_id, "UPGRADE_" .. equippedCount) then
					PlayerService:EquipItemInSlot(player_id, item_entity, "UPGRADE_" .. equippedCount)					
				else
					PlayerService:AddItemToInventory(player_id, item)
				end
				equippedCount = equippedCount + 1
			end
			for i = 2, 4, 1 do
				PlayerService:AddItemToInventory(player_id, item)
			end
		end
		for _, item in ipairs(etcs) do			
			for i = 1, 2, 1 do
				PlayerService:AddItemToInventory(player_id, item)
			end
		end

		for _, item in ipairs(weapon_mod) do			
			for i = 1, 10, 1 do
				PlayerService:AddItemToInventory(player_id, item)
			end
		end
		
		-- local item_entity = PlayerService:AddItemToInventory(player_id, "items/upgrades/lilly_extreme_item")
		-- PlayerService:EquipItemInSlot(player_id, item_entity, "UPGRADE_1")

		-- item_entity = PlayerService:AddItemToInventory(player_id, "items/upgrades/scanner_equipment_extreme_item")
		-- PlayerService:EquipItemInSlot(player_id, item_entity, "UPGRADE_2")
		
		-- item_entity = PlayerService:AddItemToInventory(player_id, "items/upgrades/detector_equipment_extreme_item")
		-- PlayerService:EquipItemInSlot(player_id, item_entity, "UPGRADE_3")
	--end
	LogService:Log("super upgrades item By Lilly ended"  )
	ConsoleService:Write("super upgrades item By Lilly ended"  )
end)
