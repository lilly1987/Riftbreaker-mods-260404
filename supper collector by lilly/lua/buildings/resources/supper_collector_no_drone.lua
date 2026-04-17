require("lua/utils/find_utils.lua")
require("lua/utils/numeric_utils.lua")
require("lua/utils/reflection.lua")
require("lua/utils/string_utils.lua")
require("lua/utils/table_utils.lua")

local building = require("lua/buildings/building.lua")
class 'supper_collector' ( building )

local function GetPlayerForEntity( entity )
    if PlayerService.GetPlayerForEntity then
        return PlayerService:GetPlayerForEntity( entity )
    end

    return 0
end

function supper_collector:__init()
	-- 드론 스포너를 쓰지 않고 일반 건물로만 동작한다.
	building.__init(self,self)
end

function supper_collector:CreateDebugStateMachine()
    if self.debug == nil then
        self.debug = self:CreateStateMachine();
        self.debug:AddState("debug", { execute="OnDebugExecute" } );
    end
end

function supper_collector:FillInitialParams()
    -- 범위는 ent의 LuaDesc database에 있는 search_radius만 참조한다.
    self.search_radius = self.data:GetFloatOrDefault("search_radius", 25.0)
    self.loot_pickup_delay = self.data:GetFloatOrDefault("loot_pickup_delay", 1.0)
    self.harvested_resources = self.harvested_resources or {}
    self.attempted_loot_entities = self.attempted_loot_entities or {}
end

function supper_collector:OnLoad()
    if building.OnLoad ~= nil then
        building.OnLoad(self)
    end

    self:FillInitialParams()
    self:CreateDebugStateMachine()
end

function supper_collector:OnInit()
    if building.OnInit ~= nil then
	    building.OnInit( self )
    end

    self:FillInitialParams()

    self.fsm = self:CreateStateMachine();
    self.fsm:AddState( "update_production", { execute="OnUpdateProductionExecute", interval=2.0 } )
    self.fsm:ChangeState("update_production")

    self:CreateDebugStateMachine()

    self.harvested_resources = {}
end

function supper_collector:OnDebugExecute()
    local message = "COLLECTED:\n"
    for resource,values in pairs( self.harvested_resources ) do
        message = message .. resource .. " = ";
        for value in Iter(self.harvested_resources[resource]) do
            message = message .. tostring(value.amount) .. ", ";
        end

        message = message .. "\n";
    end

    -- LogService:DebugText(self.entity,message)
end

function supper_collector:FindBestVegetationEntity()
    -- 드론이 찾던 조건과 동일하게, 최종 성장 단계이며 채집 가능한 식물만 고른다.
    self.predicate = self.predicate or {
        type = "",
        signature = "LootComponent",
        filter = function(entity)
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

    local position = EntityService:GetPosition(self.entity)
    local size = { x = self.search_radius, y = self.search_radius, z = self.search_radius }
    local min = VectorSub(position, size)
    local max = VectorAdd(position, size)
    return FindService:FindEntitiesByPredicateInBox( min, max, self.predicate );
end

function supper_collector:ValidateLootTarget( entity, pawn )
    if not EntityService:IsAlive(entity) then
        return false
    end

    local test_owner = pawn or PlayerService:GetPlayerControlledEnt(GetPlayerForEntity(self.entity))
    if not EntityService:IsAlive(test_owner) then
        return false
    end

    local test_entity = EntityService:GetParent( entity )
    if test_entity == INVALID_ID then
        test_entity = entity
    end

    if EntityService:GetComponent( test_entity, "PhysicsComponent") == nil then
        return false
    end

    return ItemService:CanFitResourceGiver( test_owner, test_entity )
end

function supper_collector:GetLootPickupEntity( entity )
    if not EntityService:IsAlive(entity) then
        return INVALID_ID
    end

    local parent = EntityService:GetParent( entity )
    if parent ~= INVALID_ID then
        return parent
    end

    return entity
end

function supper_collector:IsLootPickupReady( entity, pawn )
    local pickup_data = EntityService:GetComponent(entity, "PickupDataComponent")
    if pickup_data == nil then
        return true
    end

    local helper = reflection_helper(pickup_data)
    if helper == nil then
        return true
    end

    for info in Iter(helper.fly_to_inventory or {}) do
        if info.key == entity then
            return false
        end
    end

    for info in Iter(helper.pickup_protection_time or {}) do
        if (pawn == nil or info.key == pawn) and info.value ~= nil and info.value > 0.0 then
            return false
        end
    end

    return true
end

function supper_collector:NormalizeLootState( entity, loot_state )
    if loot_state == nil then
        loot_state = { first_seen = GetLogicTime(), attempted = false }
    elseif type(loot_state) == "boolean" then
        loot_state = { first_seen = GetLogicTime(), attempted = loot_state }
    elseif type(loot_state) ~= "table" then
        loot_state = { first_seen = GetLogicTime(), attempted = false }
    else
        if loot_state.first_seen == nil then
            loot_state.first_seen = GetLogicTime()
        end
        if loot_state.attempted == nil then
            loot_state.attempted = false
        end
    end

    if entity ~= nil and entity ~= INVALID_ID then
        self.attempted_loot_entities[entity] = loot_state
    end

    return loot_state
end

function supper_collector:FindNearbyLootEntities()
    self.loot_predicate = self.loot_predicate or {
        signature = "BlueprintComponent,IdComponent,ParentComponent",
        filter = function(entity)
            if EntityService:GetName(entity) ~= "#loot#" then
                return false
            end

            local target = EntityService:GetParent( entity )
            if target == INVALID_ID then
                return false
            end

            local loot_state = self:NormalizeLootState(target, self.attempted_loot_entities[target])
            if loot_state ~= nil and loot_state.attempted then
                return false
            end

            return self:ValidateLootTarget(entity, self.temp_pawn)
        end
    }

    local position = EntityService:GetPosition(self.entity)
    local size = { x = self.search_radius, y = self.search_radius, z = self.search_radius }
    local min = VectorSub(position, size)
    local max = VectorAdd(position, size)
    return FindService:FindEntitiesByPredicateInBox(min, max, self.loot_predicate)
end

function supper_collector:CollectLootEntity( loot_entity, pawn )
    local pickup_entity = self:GetLootPickupEntity( loot_entity )
    if pickup_entity == INVALID_ID then
        return false
    end

    if not self:IsLootPickupReady(pickup_entity, pawn) then
        return false
    end

    local time = GetLogicTime()
    local loot_state = self:NormalizeLootState(pickup_entity, self.attempted_loot_entities[pickup_entity])

    if loot_state.attempted then
        return false
    end

    if (time - loot_state.first_seen) < self.loot_pickup_delay then
        return false
    end

    loot_state.attempted = true
    if self:ValidateLootTarget( pickup_entity, pawn ) then
        EffectService:SpawnEffects(loot_entity, "loot_collect")
        ItemService:FlyItemToInventory(pawn, pickup_entity)
        return true
    end

    return false
end

function supper_collector:CollectNearbyLoot()
    local pawn = PlayerService:GetPlayerControlledEnt(GetPlayerForEntity(self.entity))
    if not EntityService:IsAlive(pawn) then
        return
    end

    self.temp_pawn = pawn
    local targets = self:FindNearbyLootEntities()
    self.temp_pawn = nil

    for target in Iter(targets) do
        self:CollectLootEntity(target, pawn)
    end
end

function supper_collector:CleanupAttemptedLootEntities()
    for entity,loot_state in pairs(self.attempted_loot_entities) do
        if not EntityService:IsAlive(entity) then
            self.attempted_loot_entities[entity] = nil
        else
            self:NormalizeLootState(entity, loot_state)
        end
    end
end

function supper_collector:AddHarvestedResource( resource, amount )
    -- 생산량 UI 갱신용 누적값을 저장하고, 실제 플레이어 자원도 즉시 지급한다.
    local value = self.data:GetFloatOrDefault("harvested_resources." .. resource, 0.0)
    self.data:SetFloat("harvested_resources." .. resource, value + amount )

    local player = PlayerService:GetPlayerForEntity( self.entity )
    PlayerService:AddResourceAmount(player, resource, amount, true);
end
-- ---
-- layout: default
-- title: DamageRequest
-- nav_order: 1
-- has_children: true
-- parent: Lua services
-- ---
-- ### GetDamageType
--  * (): [IdString const&](riftbreaker-wiki/docs/reflection/IdString const&)
  
-- ### GetDamageValue
--  * (): [float const&](riftbreaker-wiki/docs/reflection/float const&)
  
-- ### GetEffect
--  * (): [enum DamageEffect const&](riftbreaker-wiki/docs/reflection/enum DamageEffect const&)
  
-- ### GetEntity
--  * (): [Entity const&](riftbreaker-wiki/docs/reflection/Entity const&)
  
-- ### GetIgnoreEffect
--  * (): [enum DamageIgnoreEffect const&](riftbreaker-wiki/docs/reflection/enum DamageIgnoreEffect const&)
  

function supper_collector:DestroyHarvestTarget( target )
    if EntityService:GetComponent(target, "UnitComponent") ~= nil and HealthService:IsAlive(target) then
        -- Units can mitigate or react differently to typed damage, so use the same
        -- high raw damage approach as the built-in cheat destroy command.
        -- EntityService:CreateOrSetLifetime( target, 1, "" ) 
        QueueEvent( "DamageRequest", target, 99999, "", 0, 0 )
        -- EntityService:DestroyEntity( target, "default" )
        EntityService:RemoveEntity( target )
        return
    end

    EntityService:DestroyEntity( target, "collapse" )
end

function supper_collector:HarvestTarget( target )
    -- 대상 식물의 모든 채집 자원을 한 번에 회수한다.
    EntityService:EnsureGatherableComponent( target )

    local resources = EntityService:GetGatherableResources(target);
    if #resources == 0 then
        return false
    end

    local harvested = false
    for i=1,#resources do
        local resource_name = resources[i].first;
        local resource_amount = EntityService:GetGatherResourceAmount(target, resource_name);
        if resource_amount > 0.0 then
            self:AddHarvestedResource(resource_name, resource_amount);
            EntityService:ChangeGatherResourceAmount(target, resource_name, 0.0 );
            harvested = true
        end
    end

    resources = EntityService:GetGatherableResources(target);
    if #resources == 0 then
        -- 남은 채집 자원이 없으면 드론 수확 로직처럼 식물을 정리한다.
        -- EntityService:RemoveComponent(target, "GatherResourceComponent")
        -- EntityService:RemoveComponent(target, "LootComponent")
        -- EntityService:RemoveComponent(target, "ResourceComponent")
        self:DestroyHarvestTarget( target )
    end

    return harvested
end

function supper_collector:HarvestNearbyVegetation()
    -- 매 틱 하나의 식물을 찾아 즉시 채집한다. 드론 이동/대기 과정은 없다.
    local targets = self:FindBestVegetationEntity()
    if #targets == 0 then
        return
    end

    for target in Iter(targets) do
        if EntityService:IsAlive(target) then
            self:HarvestTarget( target )
        end
    end
end

function supper_collector:TimeoutHarvestHistory(time)
    -- 생산량 표시는 최근 60초 기록만 유지한다.
    for resourceName, data in pairs(self.harvested_resources) do
        for i, value in ipairs( data ) do
            if (time - value.timepoint) > 60.0 then
                table.remove(data, i)
            end
        end

        if #data == 0 then
            self.harvested_resources[resourceName] = nil
            self.data:RemoveKey("harvested_resources." .. resourceName);
        end
    end
end

function supper_collector:GetHarvestHistoryAverage(resourceName, time)
    -- 최근 수확량을 시간으로 나눠 초당 생산량처럼 표시한다.
    local totalValue = 0.0
    local totalTime = 0.0
    for value in Iter(self.harvested_resources[resourceName] or {}) do
        totalValue = totalValue + value.amount
        totalTime = math.max(time - value.timepoint, totalTime);
    end

    if totalTime <= 0.0 then
        return { value = 0.0, time = 1.0 }
    end

    return { value = totalValue * 1.0, time = totalTime * 1.0 };
end

function supper_collector:OnUpdateProductionExecute(state, dt)
    if g_debug_resource_harvester then
        self.debug:ChangeState("debug")
    else
        self.debug:Deactivate()
    end

    -- 수확을 먼저 처리한 뒤, 아래에서 UI용 생산량 데이터를 갱신한다.
    self:HarvestNearbyVegetation()
    self:CleanupAttemptedLootEntities()
    self:CollectNearbyLoot()

    local time = GetLogicTime();

    local keys = self.data:GetFloatKeys()

    local harvested_resources = ""
    for key in Iter( keys ) do
        local index = string.find( key, "harvested_resources.");
        if index ~= nil then
            local resource_name = string.gsub( key, "harvested_resources.", "" );
            harvested_resources = harvested_resources .. "," .. resource_name

            local harvested_amount = self.data:GetFloat(key);
            if harvested_amount > 0.0 then
                self.data:SetFloat(key, 0.0);

                local harvested_history = self.harvested_resources[resource_name] or {};
                self.harvested_resources[resource_name] = harvested_history;

                table.insert( harvested_history, { amount=harvested_amount, timepoint=time } );
            end

            local average = self:GetHarvestHistoryAverage( resource_name, time );
            self.data:SetString("production_group.rows." .. resource_name .. ".type", "production" );
            self.data:SetString("production_group.rows." .. resource_name .. ".resource", resource_name );
            self.data:SetString("production_group.rows." .. resource_name .. ".value", string.format("%.1f", average.value / average.time) );
        end
    end

    self.data:SetString("stat_categories", "production_group")
    self.data:SetString("production_group.rows", harvested_resources );

    self:TimeoutHarvestHistory( time );
end

return supper_collector;
