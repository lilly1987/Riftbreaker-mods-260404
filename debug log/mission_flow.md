missions/inventory.mission
    mod script reg

    [MapGenerator]: mission file: `missions/survival/jungle.mission`
        script          "lua/missions/survival/survival_jungle.lua"
        localization_id	"campaigns/survival/jungle.campaign"
        player_spawn_logic  "logic/loadout/player_loadout_survival.logic"
        mission_award   "items/awards/survival_jungle_award_giver_item"

    `lua/missions/survival/survival_jungle.lua`
        lua/missions/survival/survival_base.lua

        logic/missions/survival/default.logic
        lua/missions/survival/v2/dom_survival_jungle_rules_
        lua/missions/v2/dom_manager.lua

    lua\missions\campaigns\open\headquarters\headquarters_ice.lua
        lua/missions/mission_base.lua
        MissionService:ActivateMissionFlow("", "logic/missions/campaigns/open/headquarters_open_campaign.logic", "default" )
        rulesPath
            lua/missions/campaigns/open/headquarters/dom_headquarters_ice_rules_
                lua\missions\campaigns\open\headquarters\dom_headquarters_ice_rules_brutal.lua
                    lua/missions/campaigns/open/headquarters/dom_headquarters_ice_rules_default.lua
        MissionService:AddGameRule( "lua/missions/v2/dom_manager.lua", rulesPath )
            lua/missions/v2/event_manager.lua

    PlayerCreatedEvent
    PlayerInitializedEvent
    MissionFlowActivatedEvent logic/utility/player_connected.logic

    MissionFlowActivatedEvent logic/missions/survival/attack_level_1_id_2.logic
    MissionFlowActivatedEvent logic/dom/attack_level_1_entry.logic
    MissionFlowDeactivatedEvent logic/dom/attack_level_1_entry.logic
    MissionFlowDeactivatedEvent logic/missions/survival/attack_level_1_id_2.logic


-------------------------------------------------
    lua\missions\mission_generator.lua
        lua/missions/mission_base.lua