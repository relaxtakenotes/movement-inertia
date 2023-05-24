if not game.SinglePlayer() then
    util.AddNetworkString("bm_player_footstep")

    hook.Add("PlayerFootstep", "bm_network_slow_footstep", function(ply, pos, foot, soundpath, volume, rf)
        if not better_movement.cvars.force_footsteps:GetBool() then return end
        if ply:InVehicle() then return end

        if ply:Crouching() then
            should_play = (ply:GetVelocity():Length() < 60)
        else
            should_play = (ply:GetVelocity():Length() < 90)
        end

        if should_play and ply.bm_fsteptime == 0 then
            net.Start("bm_player_footstep", false)
            net.WriteEntity(ply)
            net.WriteVector(pos)
            net.WriteInt(foot, 1)
            net.WriteString(soundpath)
            net.WriteFloat(volume)
            net.Send(ply)
        end
    end)
end
 
hook.Add("SetupMove", "bm_force_foosteps", function(ply, mv)
    if not better_movement.cvars.force_footsteps:GetBool() then return end
    if ply:InVehicle() then return end

    local should_play = false
    local moving = (ply:KeyDown(IN_FORWARD) or ply:KeyDown(IN_BACK) or ply:KeyDown(IN_MOVELEFT) or ply:KeyDown(IN_MOVERIGHT))
    ply.bm_fsteptime = math.max((ply.bm_fsteptime or 0) - 1000 * FrameTime(), 0)
    local fmaxspeed = ply:GetVelocity():Length()
    -- https://github.com/lua9520/source-engine-2018-hl2_src/blob/3bf9df6b2785fa6d951086978a3e66f49427166a/game/shared/baseplayer_shared.cpp#L770
    if ply:Crouching() then
        should_play = fmaxspeed < 60
    else
        should_play = fmaxspeed < 90
    end

    if moving and ply:OnGround() and should_play and ply.bm_fsteptime == 0 then
        local exp = better_movement.cvars.sst_exponent:GetFloat()
        local mult = better_movement.cvars.sst_mult:GetFloat()
        local offset = better_movement.cvars.sst_add:GetFloat()
        local fsteptime = (fmaxspeed^exp/fmaxspeed)*mult + offset

        if not fsteptime then return end
        if fsteptime != fsteptime then return end // bandaid fix for fsteptime being 0
        if fsteptime < 100 then return end // if u walk that fast my condolences

        if ply:Crouching() then
            fsteptime = fsteptime * ply:GetCrouchedWalkSpeed() + 400
        end

        ply:PlayStepSound(0.2)

        ply.bm_fsteptime = fsteptime
    end
end)