ConsoleService:Write("ResearchCost: Autoexec loaded")
LogService:Log("ResearchCost: Autoexec loaded")

local already_applied = false

local function set_download_research_cost_to_one()
    local research_component_raw = EntityService:GetSingletonComponent("ResearchSystemDataComponent")
    if research_component_raw == nil then
        LogService:Log("ResearchCost: ResearchSystemDataComponent not found")
        return
    end
    LogService:Log("ResearchCost: research_component_raw loaded")

    local research_component = reflection_helper(research_component_raw)
    LogService:Log(tostring(research_component))

    local categories = research_component.research
    local changed = 0

    for i = 1, categories.count do
        local category = categories[i]
        local nodes = category.nodes

        for j = 1, nodes.count do
            local node = nodes[j]
            local research_costs = node.research_costs

            if research_costs ~= nil then
                for k = 1, research_costs.count do
                    local cost = research_costs[k]

                    if (cost.resource == "download" or cost.resource == "analysis") and cost.count ~= "1" then
                        cost.count = "1"
                        changed = changed + 1
                    end
                end
            end
        end
    end

    LogService:Log("ResearchCost: changed download research costs = " .. tostring(changed))
end

local function apply_once(evt)
    if already_applied then
        return
    end

    already_applied = true
    set_download_research_cost_to_one()
end

RegisterGlobalEventHandler("PlayerCreatedEvent", function(evt)
    LogService:Log("PlayerCreatedEvent")
    apply_once(evt)
end)
RegisterGlobalEventHandler("PlayerInitializedEvent", function(evt)
    LogService:Log("PlayerInitializedEvent")
    apply_once(evt)
end)
RegisterGlobalEventHandler("PlayerControlledEntityChangeEvent", function(evt)
    LogService:Log("PlayerControlledEntityChangeEvent")
    apply_once(evt)
end)
