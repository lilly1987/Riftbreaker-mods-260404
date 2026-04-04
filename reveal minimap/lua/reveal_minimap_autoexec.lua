LogService:Log("Reveal Minimap Reg")

-- 새 맵에선 효과 없음
-- ConsoleService:ExecuteCommand( "cheat_reveal_minimap 1" )

-- scripts\menu\debug_menu.dat
-- localization    "REVEAL MINIMAP"
--     command         "cheat_reveal_minimap 1"
-- }

-- "logic\missions\benchmarks\world\default.logic"
-- script "lua/graph/logic/logic_set_console_var.lua"
-- ConsoleService:ExecuteCommand( self.consoleVar .. " " .. self.consoleValue )

-- 발생 빈도를 모르겠음
RegisterGlobalEventHandler("ChangeActiveMinimapRequest", function(evt)
    -- LogService:Log("ChangeActiveMinimapRequest")
    LogService:Log("ChangeActiveMinimapRequest " .. evt:GetType())
end)

-- 안됨
RegisterGlobalEventHandler("ChangeMinimapStateRequest", function(evt)
    -- LogService:Log("ChangeMinimapStateRequest")
    LogService:Log("ChangeMinimapStateRequest " .. evt:GetState())
end)
