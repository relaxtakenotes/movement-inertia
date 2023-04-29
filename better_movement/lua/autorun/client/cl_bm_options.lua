hook.Add("PopulateToolMenu", "bm_settings_populate", function()
    spawnmenu.AddToolMenuOption("Options", "bm_8841", "bm_8841", "Options", nil, nil, function(panel)
        panel:ClearControls()
        panel:CheckBox("Enabled", better_movement.cvars.is_enabled:GetName())
        panel:CheckBox("Override weapon bases", better_movement.cvars.remove_weapon_setupmove:GetName())
        panel:CheckBox("Allow clientside inertia", better_movement.cvars.clientside_inertia:GetName())
        panel:CheckBox("Force footsteps", better_movement.cvars.force_footsteps:GetName())
        panel:ControlHelp("Forces footsteps to play even if the game thinks you're too slow")

        panel:NumSlider("Lerp Multiplier", better_movement.cvars.lerp_speed:GetName(), 0, 20, 1)
        panel:ControlHelp("Speed multiplier for how fast you want to interpolate between speeds")
        panel:NumSlider("Clientside Lerp Multiplier", better_movement.cvars.cli_lerp:GetName(), 0, 20, 1)
        panel:ControlHelp("Same as above but for the clientside inertia")
        panel:NumSlider("Enviroment Check Timer", better_movement.cvars.env_check_timer:GetName(), 0.1, 5, 1)
        panel:ControlHelp("How often to check if someone is outside or not. (The process is pretty expensive when there is more than 1 person, hence this)")

        panel:NumSlider("Add", better_movement.cvars.sst_add:GetName(), -1000, 1000)
        panel:ControlHelp("Used for step sound time calculation")
        panel:NumSlider("Exponent", better_movement.cvars.sst_exponent:GetName(), 0.05, 1, 2)
        panel:ControlHelp("Used for step sound time calculation")
        panel:NumSlider("Multiplier", better_movement.cvars.sst_mult:GetName(), 0, 5000)
        panel:ControlHelp("Used for step sound time calculation")

        panel:NumSlider("Limit jump distance", better_movement.cvars.limit_jump_distance:GetName(), 1, 10)
        panel:NumSlider("Crouch Speed", better_movement.cvars.crouch_speed:GetName(), 0.1, 1, 2)

        panel:CheckBox("Enable Boosted Run", better_movement.cvars.enable_boost:GetName())
        panel:ControlHelp("Press the sprint button two times in a 100ms time window to activate a boosted run.")
    end)

    spawnmenu.AddToolMenuOption("Options", "bm_8841", "bm_8841_speed", "Speeds", nil, nil, function(panel)
        panel:ClearControls()
        for env_typee, env_tbl in pairs(better_movement.speed) do
            for mv_typee, cvar in pairs(env_tbl) do
                panel:NumSlider(env_typee.." "..mv_typee.." speed", cvar:GetName(), 0, 1000)
            end
        end
    end)
end)

hook.Add("AddToolMenuCategories", "bm_add_category", function() 
    spawnmenu.AddToolCategory("Options", "bm_8841", "Better Movement")
end)