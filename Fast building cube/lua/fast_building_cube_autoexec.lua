pcall(require, "lua/buildings/building_base.lua")

local function StartBuildingDirectly(self)
    self.height = EntityService:GetPositionY(self.endCubeEnt)
    local x1 = EntityService:GetPositionX(self.cubeEnt)
    local x2 = EntityService:GetPositionX(self.endCubeEnt)
    self.width = (math.abs(x2 - x1) / 2) * 0.7

    EffectService:AttachEffects(self.cubeEnt, "hit_ground")
    self.cubeEnt = self.endCubeEnt
    self.printingCube = self.cubeEnt
    self.printingLine1 = nil
    self.printingLine2 = nil

    BuildingService:EnablePhysics(self.entity)
    EntityService:SetGraphicsUniform(self.meshEnt, "cMaxHeight", self.height - 1.0)
    self.buildingSM:ChangeState("building")
end

function building_base:CreateBuildingStateMachine()
    if self.buildingSM then
        return
    end

    self.buildingSM = self:CreateStateMachine()
    self.buildingSM:AddState("cube_fly", { from="*", enter="_OnCubeFlyEnter", exit="_OnCubeFlyExit", execute="_OnCubeFlyExecute" })
    self.buildingSM:AddState("cube_fly_selling", { from="*", enter="_OnCubeFlySellEnter", exit="_OnCubeFlySellExit" })
    self.buildingSM:AddState("building", { from="*", enter="_OnBuildingEnter", execute="_OnBuildingExecute", exit="_OnBuildingExit" })
    self.buildingSM:AddState("wait", { from="*", enter="_OnWaitEnter", exit="_OnWaitExit" })
    self.buildingSM:AddState("hide_scaffolding", { from="*", enter="_OnHideScafoldingEnter", execute="_OnHideScafoldingExecute", exit="_OnHideScafoldingExit" })
    self.buildingSM:AddState("selling", { from="*", enter="_OnSellEnter", execute="_OnSellExecute", exit="_OnSellExit", interval=0.1 })
    self.buildingSM:AddState("wait_for_space", { from="*", execute="_OnWaitForSpace" })
end

function building_base:_OnCubeFlyExit(state)
    if self.buildingSell == false and EntityService:IsAlive(self.endCubeEnt) and not BuildingService:IsFloor(self.entity) then
        local spaceOccupied = BuildingService:IsBuildingSpaceOccupied(self.entity)
        if spaceOccupied == false or self.checkCollision == false then
            StartBuildingDirectly(self)
            return
        end
    end

    if self.buildingSell == false then
        EffectService:DestroyEffectsByGroup(self.cubeEnt, "fly")

        local spaceOccupied = BuildingService:IsBuildingSpaceOccupied(self.entity)
        if spaceOccupied == false or self.checkCollision == false then
            BuildingService:EnablePhysics(self.entity)
            self.height = EntityService:GetPositionY(self.cubeEnt)
            self.buildingSM:ChangeState("building")
            EntityService:SetGraphicsUniform(self.meshEnt, "cMaxHeight", self.height - 1.0)
        else
            if self.timerEnt ~= nil then
                BuildingService:PauseGuiTimer(self.timerEnt)
            end
            self.buildingSM:ChangeState("wait_for_space")
        end
    end
end

function building_base:_OnWaitForSpace(state)
    if self.buildingSell == true then
        return
    end

    local spaceOccupied = BuildingService:IsBuildingSpaceOccupied(self.entity)
    if spaceOccupied == false then
        if self.timerEnt ~= nil then
            BuildingService:ResumeGuiTimer(self.timerEnt)
        end

        BuildingService:EnablePhysics(self.entity)
        if EntityService:IsAlive(self.endCubeEnt) and not BuildingService:IsFloor(self.entity) then
            StartBuildingDirectly(self)
        else
            self.height = EntityService:GetPositionY(self.cubeEnt)
            self.buildingSM:ChangeState("building")
        end

        EntityService:SetGraphicsUniform(self.meshEnt, "cMaxHeight", self.height - 1.0)
    end
end