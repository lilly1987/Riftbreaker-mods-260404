LogService:Log("Debug Log Reg") -- 맵 시작시마다 로딩

require("lua/debug_boost_values.lua")

local list={
-- "PlayerInitializedEvent",-- 캠페인/서바이벌 최초 시작 할때
-- "PlayerSpawnRequest", -- 두번 발생
-- ---
-- layout: default
-- title: PlayerSpawnRequest
-- nav_order: 1
-- has_children: true
-- parent: Lua services
-- ---
-- ### GetEntity
--  * (): [Entity const&](riftbreaker-wiki/docs/reflection/Entity const&)  
-- ### GetPlayerId
--  * (): [unsigned int const&](riftbreaker-wiki/docs/reflection/unsigned int const&)  
-- ### GetSkipPortalSequence
--  * (): [bool const&](riftbreaker-wiki/docs/reflection/bool const&)  
-- ### GetSpawnPoint
--  * (): [Entity const&](riftbreaker-wiki/docs/reflection/Entity const&)
-- ---
-- "ChangeActiveMinimapRequest", -- 하단 참조

-- "CreateActionMapperRequest",
-- "OperateActionMapperRequest",
-- "EnterFighterModeEvent",


-- "ClearCameraCulling",
-- "DisableCameraCulling",
-- "EnableCameraCulling",

-- "LuaGlobalEvent", -- 너무 많음
-- "RecreateComponentFromBlueprintRequest",


-- "ActivateEntityRequest",
-- "ActivateItemRequest",
-- "AddEntityToTraceRequest",
-- "AddMaxSpeedModifierRequest", -- 너무 많음
-- "AddPassiveSkillRequest",
-- "AmmoRemoveRequest",
-- "AttachEffectGroupRequest", -- 너무 많음
-- "BlockSaveRequest",
-- "BuildBuildingRequest",
-- "BuildFloorRequest",
-- "BuildingBuildEvent",
-- "BuildingStartEvent",
-- "BuildingVisibleInBuildMenuRequest ",
-- "ChangeBuildingRequest",
-- "ChangeBuildingStatusRequest",
-- "ChangeSelectorRequest",
-- "ChangeSubSlotRequest",
-- "CreateItemInInventoryRequest", -- 인벤토리에 아이템이 너무 많이 생김
-- "DamageRequest", -- 너무 많음
-- "DamageWithOwnerRequest",
-- "DeactivateEntityRequest",
-- "DeactivateItemRequest", -- 너무 많음
-- "DeselectEntityRequest",
-- "DestroyRequest", -- 너무 많음. EntityService:RemoveEntity로 대체
-- "DestructibleVolumeCullCellsInRadiusRequest",
-- "DisableDroneRequest",
-- "DissolveEntityRequest", -- 너무 많음
-- "DroppedResourceEvent",
-- "EmitStateMachineEventRequest", -- 너무 많음
-- "EnableDroneRequest", -- 너무 많음
-- "EnterBuildMenuEvent",
-- "EnterBuildModeEvent",
-- "EntityScanningEndEvent", -- 너무 많음
-- "EntityScanningStartEvent",-- 너무 많음
-- "EquipItemEvent", -- 너무 많음. 아이템이 너무 많이 생김 영향
-- "EquipItemRequest", -- 너무 많음
-- "FadeEntityOutRequest",-- 너무 많음
-- "FinishResurrectEvent",
-- "FinishSummonEvent",
-- "ForceBuildBuildingRequest",
-- "ForceLootContainerTypeRequest",
-- "GameStreamingAddClientEvent",
-- "GameStreamingRemoveClientEvent",
-- "GameStreamingUpdateActionEvent",
-- "HarvestStartEvent",
-- "HideComponentRequest",
-- "HideObjectiveRequest",
-- "HudDamageHighlightRequest",
-- "InteractEntityRequest", -- 너무 많음. 
-- "NetClearEntityComponentStateRequest", -- 너무 많음
-- "NewAwardEvent", -- 너무 많음. 아이템이 너무 많이 생김 영향
-- "OpenCraftingRequest",
-- "OpenEnterPortalPopupRequest",
-- "OpeningPortalStartedEvent",
-- "OpenPlanetaryScannerRequest",
-- "OpenResearchRequest",
-- "PlayerChatRequest",
-- "PlayerDiedEvent",
-- "PlayerDownEvent",
-- "PlayerPawnDestroyedEvent",
-- "PlayerReactivatedEvent",

-- "PlayTimeoutSoundRequest", -- 너무 많음
-- "PortalActivatedEvent",
-- "PortalOpeningFinishedEvent",
-- "PrepareResurrectEvent",
-- "PrepareSummonEvent",
-- "RemoveActionMapperRequest",
-- "RemoveBuildingLuaComponent",
-- "RemoveEffectsByGroupRequest", -- 너무 많음
-- "RemoveEntityToTraceRequest",
-- "RemoveMaxSpeedModifierRequest",-- 너무 많음
-- "RemovePassiveSkillRequest",
-- "RepairBuildingByPlayerRequest",
-- "ResurrectEvent",
-- "RevealComponentRequest",
-- "RiftPointActiveChangeRequest",
-- "RiftTeleportEndEvent",
-- "RiftTeleportStartEvent",
-- "ScheduleRepairBuildingRequest",
-- "SelectEntityRequest",
-- "SellBuildingRequest",
-- "SellFloorsRequest",
-- "SetBaseMovementDataRequest",-- 너무 많음
-- "SetFroceRevealMaskRequest",
-- "SetTimerRequest",
-- "ShowEndGameRequest",
-- "ShowObjectiveRequest",
-- "ShowScannableRequest",
-- "SpawnEffectGroupRequest",-- 너무 많음
-- "SpawnFromLootContainerRequest",
-- "StunWithPoseEvent",
-- "SummonEvent",
-- "SwarmChangeStateEvent",
-- "SwarmDisableSpawnRequest",
-- "SwarmEnableSpawnRequest",
-- "TeleportAppearEnter",
-- "TeleportAppearExit",
-- "UnequipItemRequest", -- 너무 많음
-- "UnitAggressiveStateEvent",
-- "UnitDeadStateEvent",
-- "UpgradeBuildingRequest",
-- "MissionFlowDeactivatedEvent",
-- "MissionFlowActivatedEvent",
-- "NewResearchAvailableEvent",
}

for _, event_name in ipairs(list) do
    RegisterGlobalEventHandler(event_name, function(evt)
        LogService:Log(event_name)
        ConsoleService:Write(event_name)
    end)
end

-- 멥 생성 직후 1000
RegisterGlobalEventHandler("PlayerInitializedEvent", function(evt)
    LogService:Log("PlayerInitializedEvent")
    ConsoleService:Write("PlayerInitializedEvent")
end)

-- 세이브 로드후
RegisterGlobalEventHandler("PlayerCreatedEvent", function(evt)
    LogService:Log("PlayerCreatedEvent")
    ConsoleService:Write("PlayerCreatedEvent")
end)

-- ---
-- layout: default
-- title: ChangeActiveMinimapRequest
-- nav_order: 1
-- has_children: true
-- parent: Lua services
-- ---
-- ### GetEntity
--  * (): [Entity const&](riftbreaker-wiki/docs/reflection/Entity const&)  
-- ### GetPlayerId
--  * (): [unsigned int const&](riftbreaker-wiki/docs/reflection/unsigned int const&)  
-- ### GetType
--  * (): [enum MinimapType const&](riftbreaker-wiki/docs/reflection/enum MinimapType const&)
RegisterGlobalEventHandler("ChangeActiveMinimapRequest", function(evt)
    -- LogService:Log("ChangeActiveMinimapRequest")
    LogService:Log("ChangeActiveMinimapRequest " .. evt:GetType())
    ConsoleService:Write("ChangeActiveMinimapRequest " .. evt:GetType())
end)

-- 안됨
RegisterGlobalEventHandler("ChangeMinimapStateRequest", function(evt)
    -- LogService:Log("ChangeMinimapStateRequest")
    LogService:Log("ChangeMinimapStateRequest " .. evt:GetState())
    ConsoleService:Write("ChangeMinimapStateRequest " .. evt:GetState())
end)

RegisterGlobalEventHandler("MissionFlowActivatedEvent", function(evt)
    LogService:Log("MissionFlowActivatedEvent " .. evt:GetName())
    ConsoleService:Write("MissionFlowActivatedEvent " .. evt:GetName())
end)

RegisterGlobalEventHandler("MissionFlowDeactivatedEvent", function(evt)
    LogService:Log("MissionFlowDeactivatedEvent " .. evt:GetName())
    ConsoleService:Write("MissionFlowDeactivatedEvent " .. evt:GetName())
end)

--------------------------------------------------------------
-- RegisterGlobalEventHandler("AddToResearchRequest", function(evt)
--     LogService:Log("AddToResearchRequest " .. evt:GetResearch())
--     ConsoleService:Write("AddToResearchRequest " .. evt:GetResearch())
-- end)

-- RegisterGlobalEventHandler("AddedToResearchEvent", function(evt)
--     LogService:Log("AddedToResearchEvent " .. evt:GetName())
--     ConsoleService:Write("AddedToResearchEvent " .. evt:GetName())
-- end)

-- RegisterGlobalEventHandler("NewResearchAvailableEvent", function(evt)
--     LogService:Log("NewResearchAvailableEvent " .. evt:GetName())
--     ConsoleService:Write("NewResearchAvailableEvent  " .. evt:GetName())
-- end)
-- RegisterGlobalEventHandler("ResearchUnlockedEvent", function(evt)
--     LogService:Log("ResearchUnlockedEvent " .. evt:GetName())
--     ConsoleService:Write("ResearchUnlockedEvent  " .. evt:GetName())
-- end)
-- RegisterGlobalEventHandler("UnlockResearchRequest", function(evt)
--     LogService:Log("UnlockResearchRequest " .. evt:GetName())
--     ConsoleService:Write("UnlockResearchRequest  " .. evt:GetName())
-- end)

-- RegisterGlobalEventHandler("OpenResearchRequest", function(evt)
--     LogService:Log("OpenResearchRequest " )
--     ConsoleService:Write("OpenResearchRequest  " )
-- end)
