hook.Add("PopulateToolMenu", "bm_settings_populate", function()
    spawnmenu.AddToolMenuOption("Options", "bm_8841", "bm_8841", "Options", nil, nil, function(panel)
        panel:ClearControls()
        panel:CheckBox("Enabled", better_movement.cvars.is_enabled:GetName())
        panel:CheckBox("Override weapon bases", better_movement.cvars.remove_weapon_setupmove:GetName())
        panel:CheckBox("Allow clientside inertia", better_movement.cvars.clientside_inertia:GetName())
        panel:CheckBox("Force footsteps", better_movement.cvars.force_footsteps:GetName())
        panel:ControlHelp("Forces footsteps to play even if the game thinks you're too slow")

        panel:ControlHelp("\n")

        panel:NumSlider("Lerp Multiplier", better_movement.cvars.lerp_speed:GetName(), 0, 20, 1)
        panel:ControlHelp("Speed multiplier for how fast you want to interpolate between speeds")
        panel:NumSlider("Clientside Lerp Multiplier", better_movement.cvars.cli_lerp:GetName(), 0, 20, 1)
        panel:ControlHelp("Same as above but for the clientside inertia")

        panel:ControlHelp("\n")

        panel:NumSlider("Enviroment Check Timer", better_movement.cvars.env_check_timer:GetName(), 0.1, 5, 1)
        panel:ControlHelp("How often to check if someone is outside or not.")
        panel:CheckBox("Predict player for the enviroment check", better_movement.cvars.env_check_predict:GetName())
        panel:NumSlider("Env. check predict time multiplier", better_movement.cvars.env_check_predict_time:GetName(), 1, 200, 1)
        panel:CheckBox("Force env. check on sudden velocity change", better_movement.cvars.env_check_sudden_velocity:GetName())
        panel:NumSlider("Env. check sudden velocity change angle", better_movement.cvars.env_check_sudden_velocity_angle:GetName(), 45, 360, 1)

        panel:ControlHelp("\n")

        panel:NumSlider("Add", better_movement.cvars.sst_add:GetName(), -1000, 1000)
        panel:NumSlider("Exponent", better_movement.cvars.sst_exponent:GetName(), 0.05, 1, 2)
        panel:NumSlider("Multiplier", better_movement.cvars.sst_mult:GetName(), 0, 5000)
        panel:ControlHelp("Used for step sound time calculation")

        panel:ControlHelp("\n")

        panel:CheckBox("Reduce velocity on landing", better_movement.cvars.stop_after_landing:GetName())
        panel:CheckBox("Disable in air movement", better_movement.cvars.disable_strafe_in_air:GetName())
        panel:NumSlider("Slowdown non forward", better_movement.cvars.slowdown_non_forward:GetName(), 0, 300, 1)
        panel:ControlHelp("Speed multiplier for when you're going in any other directuon but forward.")


        panel:NumSlider("Limit jump distance", better_movement.cvars.limit_jump_distance:GetName(), 1, 10)
        panel:NumSlider("Crouch Speed", better_movement.cvars.crouch_speed:GetName(), 0.1, 1, 2)

        panel:ControlHelp("\n")

        panel:CheckBox("Enable Boosted Run", better_movement.cvars.enable_boost:GetName())
        panel:ControlHelp("Press the sprint button two times in a 100ms time window to activate a boosted run.")

        panel:ControlHelp("\n")

        panel:Button("Reset all settings", "sv_bm_reset")
        panel:ControlHelp("Set sv_bm_reset_verification to \"agree\" before using this button. Otherwise nothing will happen.")

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