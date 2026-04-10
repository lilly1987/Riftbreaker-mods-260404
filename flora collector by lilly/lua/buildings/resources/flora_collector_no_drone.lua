require("lua/utils/find_utils.lua")
require("lua/utils/numeric_utils.lua")
require("lua/utils/reflection.lua")
require("lua/utils/string_utils.lua")
require("lua/utils/table_utils.lua")

local building = require("lua/buildings/building.lua")
class 'flora_collector' ( building )

function flora_collector:__init()
	-- 드론 스포너를 쓰지 않고 일반 건물로만 동작한다.
	building.__init(self,self)
end

function flora_collector:CreateDebugStateMachine()
    if self.debug == nil then
        self.debug = self:CreateStateMachine();
        self.debug:AddState("debug", { execute="OnDebugExecute" } );
    end
end

function flora_collector:FillInitialParams()
    -- 범위는 ent의 LuaDesc database에 있는 search_radius만 참조한다.
    self.search_radius = self.data:GetFloatOrDefault("search_radius", 25.0)
    self.harvested_resources = self.harvested_resources or {}
end

function flora_collector:OnLoad()
    if building.OnLoad ~= nil then
        building.OnLoad(self)
    end

    self:FillInitialParams()
    self:CreateDebugStateMachine()
end

function flora_collector:OnInit()
    if building.OnInit ~= nil then
	    building.OnInit( self )
    end

    self:FillInitialParams()

    self.fsm = self:CreateStateMachine();
    self.fsm:AddState( "update_production", { execute="OnUpdateProductionExecute", interval=1.0 } )
    self.fsm:ChangeState("update_production")

    self:CreateDebugStateMachine()

    self.harvested_resources = {}
end

function flora_collector:OnDebugExecute()
    local message = "COLLECTED:\n"
    for resource,values in pairs( self.harvested_resources ) do
        message = message .. resource .. " = ";
        for value in Iter(self.harvested_resources[resource]) do
            message = message .. tostring(value.amount) .. ", ";
        end

        message = message .. "\n";
    end

    LogService:DebugText(self.entity,message)
end

function flora_collector:FindBestVegetationEntity()
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

function flora_collector:AddHarvestedResource( resource, amount )
    -- 생산량 UI 갱신용 누적값을 저장하고, 실제 플레이어 자원도 즉시 지급한다.
    local value = self.data:GetFloatOrDefault("harvested_resources." .. resource, 0.0)
    self.data:SetFloat("harvested_resources." .. resource, value + amount )

    local player = PlayerService:GetPlayerForEntity( self.entity )
    PlayerService:AddResourceAmount(player, resource, amount, true);
end

function flora_collector:HarvestTarget( target )
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
        EntityService:DestroyEntity( target, "collapse" )
    end

    return harvested
end

function flora_collector:HarvestNearbyVegetation()
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

function flora_collector:TimeoutHarvestHistory(time)
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

function flora_collector:GetHarvestHistoryAverage(resourceName, time)
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

function flora_collector:OnUpdateProductionExecute(state, dt)
    if g_debug_resource_harvester then
        self.debug:ChangeState("debug")
    else
        self.debug:Deactivate()
    end

    -- 수확을 먼저 처리한 뒤, 아래에서 UI용 생산량 데이터를 갱신한다.
    self:HarvestNearbyVegetation()

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

return flora_collector;
