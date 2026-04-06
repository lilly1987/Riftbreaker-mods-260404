require("lua/utils/find_utils.lua")
require("lua/utils/reflection.lua")
require("lua/utils/throttler_utils.lua")

local base_drone = require("lua/units/air/base_drone.lua")
class 'harvester_drone' ( base_drone )

local LOCK_TYPE_HARVESTER = "harvester";
SetTargetFinderThrottler(LOCK_TYPE_HARVESTER, 3)

g_allocated_resource_drones = {}

-- 식생과 자원 광맥은 비슷한 데이터를 서로 다른 엔진 API로 제공합니다.
-- 이 헬퍼들로 수확 상태 머신이 대상 종류를 직접 신경 쓰지 않게 합니다.
local function GetGatherableResources( target, is_vegetation )
    if is_vegetation then
        return EntityService:GetGatherableResources(target);
    else
        local result = EntityService:GetResourceAmount(target)
        if result.second > 0 then
            return { result }
        end
    end

    return {}
end

local function GetGatherableResourceAmount( target, resource, is_vegetation )
    if is_vegetation then
        return EntityService:GetGatherResourceAmount(target, resource);
    end

    return EntityService:GetResourceAmount(target).second
end

local function ChangeGatherableResourceAmount( target, resource, amount, is_vegetation )
    if is_vegetation then
        return EntityService:ChangeGatherResourceAmount(target, resource, amount );
    end

    EntityService:ChangeResourceAmount(target, amount)
end

function harvester_drone:__init()
	base_drone.__init(self,self)
end

function harvester_drone:FindBestVegetationEntity(owner, source)
    -- 더 큰 식생을 우선 선택하고, 크기가 같으면 거리를 기준으로 고릅니다.
    -- 주변의 작은 식물만 반복 수확하느라 더 좋은 대상을 놓치지 않게 하기 위함입니다.
    self.predicate = self.predicate or {
        type=self.search_type,
        signature="LootComponent",
        filter = function(entity) 
            if self:IsTargetLocked(entity, LOCK_TYPE_HARVESTER) then
                return false
            end

            if IndexOf(self.exclude_targets, entity) ~= nil then
                return false
            end

            
            if not EntityService:IsInFinalVegetationChainPhase( entity ) then
                return false
            end

            local lootComponent = EntityService:GetConstComponent(entity, "LootComponent")
            if not lootComponent or not reflection_helper( lootComponent ).is_gatherable then
                return false
            end

            return true
        end
    };

    local entities = FindService:FindEntitiesByPredicateInRadius( owner, self.search_radius, self.predicate );

    local best = {
        entity = INVALID_ID,
        distance = nil,
        index = -1
    };

    for entity in Iter( entities ) do
        local name = EntityService:GetBlueprintName( entity );

        local index = -1;
        if ( string.find( name, "very_large") ) then
            index = 5
        elseif ( string.find( name, "large") ) then
            index = 4
        elseif ( string.find( name, "big") ) then
            index = 4
        elseif ( string.find( name, "medium") ) then
            index = 3
        elseif ( string.find( name, "very_small") ) then
            index = 1
        elseif ( string.find( name, "small") ) then
            index = 2
        else
            index = 0
        end
        local distance = EntityService:GetDistanceBetween( source, entity );

        if best.entity == INVALID_ID or index > best.index then
            best.entity = entity
            best.distance = distance;
            best.index = index
        elseif index == best.index and best.distance > distance then
            best.entity = entity
            best.distance = distance;
            best.index = index
        end
    end

    return best.entity
end

function harvester_drone:FindResourceVeinEntity(owner, source)
    self.player = PlayerService:GetPlayerForEntity( owner )
    -- 이미 다른 구조물에 점유/표시된 광맥은 건너뛰고, 플레이어가 해금한 자원만 대상으로 삼습니다.
    self.predicate = self.predicate or {
        type=self.search_type,
        signature="ResourceComponent,GridMarkerComponent",
        filter = function(entity) 
            if self:IsTargetLocked(entity, LOCK_TYPE_HARVESTER) then
                return false
            end

            if IndexOf(self.exclude_targets, entity) ~= nil then
                return false
            end

            local position = EntityService:GetPosition(entity)
            if FindService:IsGridMarkedWithLayer(position, "OwnerLayerComponent") then
                return false
            end

            local result = EntityService:GetResourceAmount(entity)
            if not PlayerService:IsResourceUnlocked(self.player, result.first) then
                return false
            end

            return true
        end
    };

    local entities = FindService:FindEntitiesByPredicateInRadius( owner, self.search_radius, self.predicate );
    if #entities > 0 then
        local parents = {}
        for entity in Iter(entities) do
            table.insert(parents, { entity = entity, parent = EntityService:GetParent(entity), distance = EntityService:GetDistanceBetween(owner,entity)})
        end

        -- 모든 드론이 첫 번째 마커에 몰리지 않도록, 배정된 드론 수가 적은 부모 광맥을 우선합니다.
        local sorter = function(lhs,rhs)
            return #(g_allocated_resource_drones[lhs.parent] or { distance = 0.0 }) < #(g_allocated_resource_drones[rhs.parent] or {})
        end

        table.sort( parents, sorter )

        return parents[1].entity
    end

    return INVALID_ID
end

function harvester_drone:FillInitialParams()
    if self.data:HasFloat("drone_search_radius") then
        self.search_radius = self.data:GetFloat("drone_search_radius")
    else
        self.search_radius = self.data:GetFloat("search_radius")
    end

    self.search_type = self.data:GetStringOrDefault("search_type","");

    self.harvest_vegetation = self.data:GetIntOrDefault("harvest_vegetation", 1 ) == 1; --
    self.harvest_storage = self.data:GetFloat("harvest_storage"); -- 무시
    self.harvest_duration = self.data:GetFloat("harvest_time"); -- 무시
    self.unload_duration = self.data:GetFloat("unload_time");
    self.exclude_targets = self.exclude_targets or {};

    if self.debug == nil then
        self.debug = self:CreateStateMachine();
        self.debug:AddState("debug", { execute="OnDebugExecute" } );
    end
end

function harvester_drone:OnInit()
    self:FillInitialParams();

    -- local tick_interval = math.max(0.5, self.harvest_duration / 3.0 - RandFloat(-0.2, 0.2))
    local tick_interval = 0.5
    self.fsm = self:CreateStateMachine();
    self.fsm:AddState("harvest", { enter="OnHarvestEnter", execute="OnHarvestExecute", exit="OnHarvestExit", interval=tick_interval} );
    self.fsm:AddState("unload", { enter="OnUnloadEnter", execute="OnUnloadExecute", exit="OnUnloadExit", interval=tick_interval } );

    self:ClearStorage();
end

function harvester_drone:OnDebugExecute()
    local message = "HARVESTED:\n"
    for resource, amount in pairs( self.storage ) do
        message = message .. resource .. " = " .. tostring(amount) .. "\n";
    end

    LogService:DebugText(self.entity,message)

    local target = self:GetDroneActionTarget();
    if target ~= INVALID_ID then
        local message = "GATHERABLE:\n"

        local resources = EntityService:GetGatherableResources(target);
        for i=1,#resources do
            local resource_name = resources[i].first;
            message = message .. resources[i].first .. " = " .. tostring(resources[i].second) .. "\n";
        end

        LogService:DebugText(target, message)
    end
end

function harvester_drone:LockTarget( target, lock_type )
    base_drone.LockTarget( self, target, lock_type )

    if self.harvest_vegetation then
        return
    end

    -- 자원 마커는 광맥 엔티티의 자식일 수 있으므로 부모 기준으로 배정을 기록합니다.
    -- 이렇게 해야 같은 광맥의 여러 마커를 하나의 대상으로 보고 분산할 수 있습니다.
    local parent = EntityService:GetParent(target)
    if parent ~= INVALID_ID then
        target = parent
    end

    if g_allocated_resource_drones[ target ] == nil then
        g_allocated_resource_drones[ target ] = {}
    end

    table.insert(g_allocated_resource_drones[ target ], self.entity )
end

function harvester_drone:UnlockTarget( target, lock_type )
    base_drone.UnlockTarget( self, target, lock_type )

    if self.harvest_vegetation then
        return
    end

    local parent = EntityService:GetParent(target)
    if parent ~= INVALID_ID then
        target = parent
    end

    if g_allocated_resource_drones[ target ] == nil then
        g_allocated_resource_drones[ target ] = {}
    end

    table.remove(g_allocated_resource_drones[ target ], self.entity )
end

function harvester_drone:OnLoad()
    self:FillInitialParams();

    if not self.current_storage then
        self.current_storage = {}
        for resource, _ in pairs( self.storage ) do
            self.current_storage[ resource ] = 0.0
        end
    end
    base_drone.OnLoad( self )
end

function harvester_drone:FindActionTarget()
    if self:GetCurrentStorage() >= self.harvest_storage then
        return INVALID_ID
    end

    local owner = self:GetDroneOwnerTarget();
    if not EntityService:IsAlive( owner ) then
        return INVALID_ID
    end

    if IsRequestThrottled(LOCK_TYPE_HARVESTER) then
        return INVALID_ID
    end

    if self.harvest_vegetation then
        local target = self:FindBestVegetationEntity(owner, self.entity)
        if target ~= INVALID_ID then
            EntityService:EnsureGatherableComponent( target )
            self:LockTarget( target, LOCK_TYPE_HARVESTER );
        end

        return target;
    else
        local target = self:FindResourceVeinEntity(owner, self.entity)
        if target ~= INVALID_ID then
            self:LockTarget( target, LOCK_TYPE_HARVESTER );
        end

        return target;
    end
end

function harvester_drone:OnDroneOwnerAction( target )
    self.fsm:ChangeState("unload")
end

function harvester_drone:OnDroneTargetAction( target )
    self.fsm:ChangeState("harvest")
end

function harvester_drone:OnUnloadEnter(state)
    state:SetDurationLimit(self.unload_duration)
    local owner = self:GetDroneOwnerTarget();
    local player = PlayerService:GetPlayerForEntity( owner )

    for resource, amount in pairs( self.storage ) do
        if not PlayerService:IsResourceUnlocked( player, resource ) then
            self:UpdateResourceStorage(resource, -amount);
        end
    end
end

function harvester_drone:UnloadResource( resource, amount )
    local owner = self:GetDroneOwnerTarget();
    if owner ~= INVALID_ID then
        local database = EntityService:GetDatabase( owner )
        if database ~= nil then
            -- 건물은 이 카운터를 읽어 생산량 통계를 갱신합니다.
            local value = database:GetFloatOrDefault("harvested_resources." .. resource, 0.0)
            database:SetFloat("harvested_resources." .. resource, value + amount )
        end
    end

    local player = PlayerService:GetPlayerForEntity( owner )
    PlayerService:AddResourceAmount(player, resource, amount, true);

    self:UpdateResourceStorage(resource, -amount);
end

function harvester_drone:OnUnloadExecute(state, dt)
    local max_change_amount = ( self.harvest_storage / self.unload_duration ) * dt;
    for resource, amount in pairs( self.storage ) do
        local change_amount = max_change_amount;
        if amount < max_change_amount then
            change_amount = amount
        end

        -- local max_player_storage = PlayerService:GetResourceLimit( resource );
        -- local curr_player_storage = PlayerService:GetResourceAmount(PlayerService:GetLeadingPlayer(), resource );

        -- local player_storage = max_player_storage - curr_player_storage;
        -- if change_amount > player_storage then
        --     change_amount = player_storage
        -- end

        -- if change_amount > 0 then
            self:UnloadResource(resource, change_amount);
        --end
    end

    if self:GetCurrentStorage() <= 0.0 then
        state:Exit()
    end
end

function harvester_drone:OnUnloadExit(state)
    for resource, amount in pairs( self.storage ) do
        self:UnloadResource(resource, amount )
    end

    self:ClearStorage();

    self:SetOwnerActionFinished();
    Clear(self.exclude_targets)
end

function harvester_drone:OnHarvestEnter(state)
    if g_debug_resource_harvester then
        self.debug:ChangeState("debug")
    else
        self.debug:Deactivate()
    end

    state:SetDurationLimit(self.harvest_duration)

    local target = self:GetDroneActionTarget();
    Insert(self.exclude_targets, target)

    -- current_storage는 이번 수확 사이클에서 대상에게서 가져온 양을 기록합니다.
    -- 대상의 실제 자원량은 종료 시 한 번에 반영해, 중단된 사이클도 한 번의 변화량으로 처리합니다.
    self.current_storage = {}

    local resources = GetGatherableResources( target, self.harvest_vegetation )
    if #resources == 0 then
        state:Exit()
        return;
    end

    for i=1,#resources do
        local resource_name = resources[i].first;
        self.current_storage[ resource_name ] = 0.0

        local current_amount = self.storage[ resource_name ];
        self.storage[ resource_name ] = current_amount or 0.0
    end

    EffectService:AttachEffects(self.entity, "work");
end

function harvester_drone:GetCurrentStorage()
    local current_storage = 0;
    for resource, amount in pairs( self.storage ) do
        current_storage = current_storage + amount;
    end

    return current_storage
end

function harvester_drone:UpdateResourceStorage( resource, change_amount )
    -- 드론 적재 한도에 맞춰 수확량을 제한하고, 실제로 저장된 양을 반환합니다.
    local current_storage = self:GetCurrentStorage();

    local storage_left = self.harvest_storage - current_storage
    if  change_amount > storage_left then
        change_amount = storage_left
    end

    local current_amount = self.storage[ resource ];
    self.storage[ resource ] = current_amount + change_amount;

    --EntityService:SetGraphicsUniform( self.entity, "cGlowFactor", math.max( 0.5, (current_storage + change_amount) / self.harvest_storage ) );

    return change_amount;
end

function harvester_drone:ClearStorage()
    self.storage = {}

    EntityService:SetGraphicsUniform( self.entity, "cGlowFactor", 0.5 );
end

function harvester_drone:OnHarvestExecute(state, dt)
    local max_change_amount = ( self.harvest_storage / self.harvest_duration ) * dt;

    local target = self:GetDroneActionTarget();

    if not EntityService:IsAlive( target ) then
        return state:Exit()
    end

    for resource, _ in pairs( self.storage ) do
        local currentAmount = self.current_storage[ resource ] or 0.0
        local resourceAmount = GetGatherableResourceAmount(target, resource, self.harvest_vegetation);
        -- 대상 자원량은 OnHarvestExit에서 반영되므로,
        -- 이번 사이클에 이미 예약된 수확량을 뺀 남은 양을 기준으로 계산합니다.
        resourceAmount = resourceAmount - currentAmount

        local harvestAmount = self:UpdateResourceStorage( resource, math.min( resourceAmount, max_change_amount ) );
        if harvestAmount > 0.0 then
            self.current_storage[ resource ] = currentAmount + harvestAmount
            --ChangeGatherableResourceAmount( target, resource, resourceAmount - harvestAmount, self.harvest_vegetation )
        else
           state:Exit()
        end

    end
end

function harvester_drone:OnHarvestExit()
    local target = self:GetDroneActionTarget();
    if EntityService:IsAlive( target ) then

        -- 이번 사이클에서 수확한 자원량을 대상 엔티티에 반영합니다.
        for resource, harvestAmount in pairs( self.current_storage ) do
            local resourceAmount = GetGatherableResourceAmount(target, resource, self.harvest_vegetation);
            ChangeGatherableResourceAmount( target, resource, resourceAmount - harvestAmount, self.harvest_vegetation )
        end

        -- 고갈된 대상은 제거해서 탐색기가 빈 식생이나 자원 마커를 계속 선택하지 않게 합니다.
        local resources = GetGatherableResources(target, self.harvest_vegetation);
        if #resources == 0 then
            EntityService:RemoveComponent(target, "GatherResourceComponent")
            EntityService:RemoveComponent(target, "LootComponent")
            EntityService:RemoveComponent(target, "ResourceComponent")

	        EntityService:DestroyEntity( target, "collapse" )
        end
    end

    EffectService:DestroyEffectsByGroup(self.entity, "work");

    self:UnlockAllTargets();
    self:SetTargetActionFinished();
end

return harvester_drone;
