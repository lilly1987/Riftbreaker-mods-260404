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
    -- 조건에 맞는 식생 목록에서 랜덤으로 하나를 선택합니다.
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

    if #entities > 0 then
        return entities[math.random(1, #entities)]
    end

    return INVALID_ID
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
        return entities[math.random(1, #entities)]
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
    self.exclude_targets = self.exclude_targets or {};

    if self.debug == nil then
        self.debug = self:CreateStateMachine();
        self.debug:AddState("debug", { execute="OnDebugExecute" } );
    end
end

function harvester_drone:OnInit()
    self:FillInitialParams();

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

    base_drone.OnLoad( self )
end

function harvester_drone:FindActionTarget()
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
    self:SetOwnerActionFinished();
end

function harvester_drone:OnDroneTargetAction( target )
    self.fsm:ChangeState("harvest")
end

function harvester_drone:OnUnloadEnter(state)
    state:Exit()
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
end

function harvester_drone:OnUnloadExecute(state, dt)
    state:Exit()
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

    local target = self:GetDroneActionTarget();
    Insert(self.exclude_targets, target)

    local resources = GetGatherableResources( target, self.harvest_vegetation )
    if #resources == 0 then
        state:Exit()
        return;
    end

    for i=1,#resources do
        local resource_name = resources[i].first;
        local resource_amount = GetGatherableResourceAmount(target, resource_name, self.harvest_vegetation);
        if resource_amount > 0.0 then
            self:UnloadResource(resource_name, resource_amount);
            ChangeGatherableResourceAmount( target, resource_name, 0.0, self.harvest_vegetation )
        end
    end

    state:Exit()
end

function harvester_drone:ClearStorage()
    self.storage = {}

    EntityService:SetGraphicsUniform( self.entity, "cGlowFactor", 0.5 );
end

function harvester_drone:OnHarvestExecute(state, dt)
    state:Exit()
end

function harvester_drone:OnHarvestExit()
    local target = self:GetDroneActionTarget();
    if EntityService:IsAlive( target ) then

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
