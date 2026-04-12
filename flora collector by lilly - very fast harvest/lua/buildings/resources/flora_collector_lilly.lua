require("lua/utils/string_utils.lua")
require("lua/utils/table_utils.lua")

local drone_spawner_building = require("lua/buildings/drone_spawner_building.lua")
class 'flora_collector' ( drone_spawner_building )

function flora_collector:__init()
	drone_spawner_building.__init(self,self)
end

function flora_collector:CreateDebugStateMachine()
    -- 생산량 갱신 루프를 방해하지 않고 디버그 표시만 켜고 끌 수 있도록
    -- 별도 상태 머신으로 관리합니다.
    if self.debug == nil then
        self.debug = self:CreateStateMachine();
        self.debug:AddState("debug", { execute="OnDebugExecute" } );
    end
end

function flora_collector:OnLoad()
    drone_spawner_building.OnLoad(self)

    self:CreateDebugStateMachine()
end

function flora_collector:OnInit()
	drone_spawner_building.OnInit( self )

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

function flora_collector:TimeoutHarvestHistory(time)
    -- 건물 UI에는 최근 초당 생산량을 표시하므로, 오래된 샘플은 계속 누적하지 않고 제거합니다.
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
    -- 수확량과 샘플 경과 시간을 함께 반환합니다. 호출부에서 둘을 나눠 자원별 최근 생산량을 표시합니다.
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

    local time = GetLogicTime();

    local keys = self.data:GetFloatKeys()

    local harvested_resources = ""
    for key in Iter( keys ) do
        -- 드론이 소유자 데이터베이스에 기록한 수확량을 읽고 초기화한 뒤,
        -- 최근 평균값을 UI 행 데이터로 반영합니다.
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
