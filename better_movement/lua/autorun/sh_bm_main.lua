better_movement = {}
better_movement.speed = {}

local cvar_flags = {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_GAMEDLL}
better_movement.cvars = {
    is_enabled = CreateConVar("sv_bm_enabled", 1, cvar_flags, "Enable the better footsteps thing."),
    sst_add = CreateConVar("sv_bm_stepsoundtime_add", 0, cvar_flags, "Offset for the footstep sound time. (formula: (fMaxSpeed^exp/fMaxSpeed)*mult + offset"),
    sst_exponent = CreateConVar("sv_bm_stepsoundtime_exponent", 0.6, cvar_flags, "Exponent for the footstep sound time. (formula: (fMaxSpeed^exp/fMaxSpeed)*mult + offset"),
    sst_mult = CreateConVar("sv_bm_stepsoundtime_mult", 2600, cvar_flags, "Multiplier for the footstep sound time. (formula: (fMaxSpeed^exp/fMaxSpeed)*mult + offset"),
    remove_weapon_setupmove = CreateConVar("sv_bm_remove_weapon_setupmove", 1, cvar_flags, "Remove all the hooks related to modifying movements from weapon packs. Once removed only restarting the server will return them."),
    lerp_speed = CreateConVar("sv_bm_lerp_multiplier", 3, cvar_flags, "How fast you want to transition between speeds."),
    clientside_inertia = CreateConVar("sv_bm_clientside_inertia", 1, cvar_flags, "Allow some inertia to be calculated and applied clientside."),
    cli_lerp = CreateConVar("sv_bm_clientside_inertia_lerp", 8, cvar_flags, "How fast to lerp between some stuff for inertia."),
    force_footsteps = CreateConVar("sv_bm_force_footsteps", 1, cvar_flags, "Force footsteps to play even if the game thinks you're too slow for it."),
    limit_jump_distance = CreateConVar("sv_bm_limit_jump_distance", 4, cvar_flags, "Limit jump distance magic number!"),
    crouch_speed = CreateConVar("sv_bm_crouch_speed", 0.3, cvar_flags, "Crouch speed time..."),
    disable_strafe_in_air = CreateConVar("sv_bm_disable_strafe_in_air", 1, cvar_flags, "Disable strafing in air."),
    stop_after_landing = CreateConVar("sv_bm_stop_after_landing", 1, cvar_flags, "Reduce velocity after landing."),
    enable_boost = CreateConVar("sv_bm_enable_boosted_run", 1, cvar_flags, "Enable a custom boosted run thing."),
    env_check_timer = CreateConVar("sv_bm_env_check_timer", 1, cvar_flags, "How often to run the enviroment check (in seconds)."),
    env_check_predict = CreateConVar("sv_bm_env_check_predict", 1, cvar_flags, "Whether or not to predict a player for the enviroment check given the env check timer."),
    env_check_predict_time = CreateConVar("sv_bm_env_check_predict_time", 75, cvar_flags, "Time multiplier for env check prediction."),
    env_check_sudden_velocity = CreateConVar("sv_bm_env_check_sudden_velocity", 1, cvar_flags, "Force and enviroment check if the velocity has changed too much."),
    env_check_sudden_velocity_angle = CreateConVar("sv_bm_env_check_sudden_velocity_angle", 60, cvar_flags, "How big of a velocity change is considered sudden"),
    slowdown_non_forward = CreateConVar("sv_bm_slowdown_non_forward", 0.7, cvar_flags, "Speed multiplier for when you're going in any other directuon but forward."),
    reset_verification = CreateConVar("sv_bm_reset_verification", "no", cvar_flags, "Write agree to this convar to allow cvar resetting.")
}

concommand.Add("sv_bm_reset", function()
    if better_movement.cvars.reset_verification:GetString() != "agree" then 
        print("You hadn't agreed to allow cvar resets: ", better_movement.cvars.reset_verification:GetName()) 
        return 
    end

    for name, cvar in pairs(better_movement.cvars) do
        cvar:Revert()
        print(cvar:GetName(), "reset!")
    end

    for env, mult in pairs(better_movement.speed) do
        for mv, speed in pairs(better_movement.speed[env]) do
            better_movement.speed[env][mv]:Revert()
            print(better_movement.speed[env][mv]:GetName(), "reset!")
        end
    end

    better_movement.cvars.reset_verification:SetString("no")
end, nil, "Reset all cvars used by better movement.", {FCVAR_GAMEDLL})

for env, mult in pairs({["outdoors"] = 1, ["indoors"] = 0.75}) do
    better_movement.speed[env] = {}
    for mv, speed in pairs({["normal"] = 200, ["run"] = 350, ["slow"] = 100, ["boosted_run"] = 400}) do
        better_movement.speed[env][mv] = CreateConVar("sv_bm_"..env.."_"..mv, speed * mult, cvar_flags)
    end
end

local function traceable_to_sky(pos, offset)
    local tr = util.TraceLine({start=pos + offset, endpos=pos + Vector(offset.x, offset.y, 100000000), mask=MASK_NPCWORLDSTATIC})
    local temp = util.TraceLine({start=tr.StartPos, endpos=pos, mask=MASK_NPCWORLDSTATIC})
    if temp.HitPos == pos and not temp.StartSolid and tr.HitSky then return true end
    return false
end

local function get_env_state(pos)
    local tr_1 = traceable_to_sky(pos, Vector(0,0,0))
    local tr_2 = traceable_to_sky(pos, Vector(120,0,0))
    local tr_3 = traceable_to_sky(pos, Vector(0,120,0))
    local tr_4 = traceable_to_sky(pos, Vector(-120,0,0))
    local tr_5 = traceable_to_sky(pos, Vector(0,-120,0))
    if (tr_1 or tr_2 or tr_3 or tr_4 or tr_5) then return "outdoors" else return "indoors" end
end

local function calculate_env(ply, mv)
    // atomic sludge
    ply.bm_env_state_prev = ply.bm_env_state or "outdoors"
    local ang = ply:GetVelocity():Angle().y
    local angle_delta = math.abs((ply.bm_env_ang_last or ang) - ang)

    local pos = ply:GetPos()
    local pos_dist = (ply.bm_last_pos or pos):Distance(pos)
    ply.bm_last_pos = pos

    local pos_dist_2 = (ply.bm_last_pos_2 or pos + Vector(9999, 9999, 9999)):Distance(pos)
    
    local timer_trigger = (ply.bm_env_check_timer or 99999) > better_movement.cvars.env_check_timer:GetFloat()
    local angle_trigger = angle_delta > better_movement.cvars.env_check_sudden_velocity_angle:GetFloat() and better_movement.cvars.env_check_sudden_velocity:GetBool()
    local pos_trigger = pos_dist > 100
    local pos_2_trigger = pos_dist_2 > 10

    if (timer_trigger or angle_trigger or pos_trigger) and pos_2_trigger then
        ply.bm_env_ang_last = ang
        ply.bm_last_pos_2 = pos
        
        local vel = ply:GetVelocity()
        vel.z = 0    

        if better_movement.cvars.env_check_predict:GetBool() then
            local mins, maxs = ply:GetCollisionBounds()
            maxs = maxs - Vector(0,0,64)
            local tr = util.TraceHull({
                start = ply:EyePos(),
                endpos = ply:EyePos() + vel * FrameTime() * better_movement.cvars.env_check_timer:GetFloat() * better_movement.cvars.env_check_predict_time:GetFloat(),
                maxs = maxs,
                mins = mins,
                filter = ply
            })
            ply.bm_env_state = get_env_state(tr.HitPos)
        else
            ply.bm_env_state = get_env_state(ply:GetPos())
        end

        ply.bm_env_check_timer = 0
    end
    ply.bm_env_check_timer = (ply.bm_env_check_timer or 0) + FrameTime()

    if not ply.bm_env_state then ply.bm_env_state = "outdoors" end
    if not ply.bm_env_state_prev then ply.bm_env_state_prev = "outdoors" end   
end

local function calculate_walk_state(ply, mv)
    ply.bm_walk_state_prev = ply.bm_walk_state or "normal"
    ply.bm_walk_state = "normal"

    ply.bm_boosted_run_timer = math.max((ply.bm_boosted_run_timer or 0) - FrameTime(), 0)
    if ply.bm_boosted_run_timer == 0 then ply.bm_boosted_run_counter = 0 end

    if mv:KeyDown(IN_SPEED) then
        if mv:KeyWasDown(IN_SPEED) != mv:KeyDown(IN_SPEED) then ply.bm_boosted_run_counter = (ply.bm_boosted_run_counter or 0) + 1 end
        ply.bm_boosted_run_timer = 0.1
        ply.bm_walk_state = "run"
        if better_movement.cvars.enable_boost:GetBool() and ply.bm_boosted_run_counter >= 2 then ply.bm_walk_state = "boosted_run" end
    end

    if mv:KeyDown(IN_WALK) then ply.bm_walk_state = "slow" end
end

local function update_on_state_change(ply)
    if (ply.bm_env_state != ply.bm_env_state_prev or ply.bm_walk_state != ply.bm_walk_state_prev) or ply.bm_first_time == nil then
        ply.bm_lerp_value = 0

        ply.bm_lerp_to = better_movement.speed[ply.bm_env_state][ply.bm_walk_state]:GetFloat()
        ply.bm_lerp_from = ply:GetVelocity():Length()

        if ply.bm_walk_state == "boosted_run" then
            ply:SetRunSpeed(better_movement.speed[ply.bm_env_state]["boosted_run"]:GetFloat())
        else
            ply:SetRunSpeed(better_movement.speed[ply.bm_env_state]["run"]:GetFloat())
        end

        ply:SetWalkSpeed(better_movement.speed[ply.bm_env_state]["normal"]:GetFloat())
        ply:SetSlowWalkSpeed(better_movement.speed[ply.bm_env_state]["slow"]:GetFloat())

        ply.bm_first_time = false
    end
end

local function interpolate_speed(ply, mv, maxspeed)
    ply.bm_wish_forward = math.Clamp(mv:GetForwardSpeed(), -maxspeed, maxspeed)
    ply.bm_wish_side = math.Clamp(mv:GetSideSpeed(), -maxspeed, maxspeed)

    if not ply.bm_sidespeed then ply.bm_sidespeed = 0 end
    if not ply.bm_forwardspeed then ply.bm_forwardspeed = 0 end

    if IsFirstTimePredicted() then
        ply.bm_sidespeed_last = ply.bm_sidespeed
        if ply.bm_wish_forward != ply.bm_forwardspeed or ply.bm_wish_side != ply.bm_sidespeed then
            ply.bm_sidespeed = math.Approach(ply.bm_sidespeed, ply.bm_wish_side, math.abs(ply.bm_sidespeed - ply.bm_wish_side) * FrameTime() * better_movement.cvars.cli_lerp:GetFloat() + FrameTime())
            ply.bm_forwardspeed = math.Approach(ply.bm_forwardspeed, ply.bm_wish_forward, math.abs(ply.bm_forwardspeed - ply.bm_wish_forward) * FrameTime() * better_movement.cvars.cli_lerp:GetFloat() + FrameTime())
        end
    end
end

local function apply_movement_changes(ply, mv, maxspeed)
    local onground = ply:OnGround()
    if ply:KeyDown(IN_SPEED) and ply.bm_was_onground != onground and ply:KeyDown(IN_JUMP) and !ply:OnGround() and ply:WaterLevel() < 3 then
        ply:SetVelocity(Vector(-ply:GetVelocity().x/math.max(1,(better_movement.cvars.limit_jump_distance:GetFloat())),-ply:GetVelocity().y/math.max(1,better_movement.cvars.limit_jump_distance:GetFloat()),0))
    end
    ply.bm_was_onground = onground

    if ply.bm_lerp_value == 1 then
        if ply.bm_walk_state == "boosted_run" then
            ply:SetRunSpeed(better_movement.speed[ply.bm_env_state]["boosted_run"]:GetFloat())
        else
            ply:SetRunSpeed(better_movement.speed[ply.bm_env_state]["run"]:GetFloat())
        end

        ply:SetWalkSpeed(better_movement.speed[ply.bm_env_state]["normal"]:GetFloat())
        ply:SetSlowWalkSpeed(better_movement.speed[ply.bm_env_state]["slow"]:GetFloat())
    else
        ply:SetMaxSpeed(maxspeed)
        ply:SetRunSpeed(maxspeed)
        ply:SetWalkSpeed(maxspeed)
        ply:SetSlowWalkSpeed(maxspeed)
    end

    ply:SetDuckSpeed(better_movement.cvars.crouch_speed:GetFloat())
    ply:SetUnDuckSpeed(better_movement.cvars.crouch_speed:GetFloat())

    if not onground and ply:GetMoveType() == MOVETYPE_WALK and ply:WaterLevel() == 0 and better_movement.cvars.disable_strafe_in_air:GetBool() then
        ply.bm_sidespeed = 0
        ply.bm_forwardspeed = 0
    end

    if ply:GetMoveType() == MOVETYPE_WALK then
        local mult = better_movement.cvars.slowdown_non_forward:GetFloat()
        local side = ply.bm_sidespeed * mult
        if ply.bm_forwardspeed >= 0 then mult = 1 end
        local forward = ply.bm_forwardspeed * mult

        mv:SetSideSpeed(side)
        mv:SetForwardSpeed(forward)
    end
end

hook.Add("SetupMove", "bm_regulate_speed", function(ply, mv)
    if not better_movement.cvars.is_enabled:GetBool() then return end

    calculate_walk_state(ply, mv)
    calculate_env(ply, mv)
    update_on_state_change(ply)

    if IsFirstTimePredicted() then
        ply.bm_lerp_value = math.Clamp((ply.bm_lerp_value or 0) + FrameTime() * better_movement.cvars.lerp_speed:GetFloat(), 0, 1)
    end
    local maxspeed = Lerp(ply.bm_lerp_value, ply.bm_lerp_from, ply.bm_lerp_to)

    interpolate_speed(ply, mv, maxspeed)
    apply_movement_changes(ply, mv, maxspeed)
end)

hook.Add("PlayerStepSoundTime", "bm_stepsoundtime", function(ply, iType, bWalking)
    if ply:InVehicle() then return end

    local fmaxspeed = ply:GetMaxSpeed()
    local exp = better_movement.cvars.sst_exponent:GetFloat()
    local mult = better_movement.cvars.sst_mult:GetFloat()
    local offset = better_movement.cvars.sst_add:GetFloat()
    local fsteptime = (fmaxspeed^exp/fmaxspeed)*mult + offset

    if (iType == STEPSOUNDTIME_ON_LADDER) then
        fsteptime = fsteptime + 100
    elseif (iType == STEPSOUNDTIME_WATER_KNEE) then
        fsteptime = fsteptime + 200
    end

    if (ply:Crouching()) then
        fsteptime = fsteptime + 50
    end

    ply.bm_fsteptime = fsteptime

    return fsteptime
end)

hook.Add("OnPlayerHitGround", "bm_land", function(ply, inWater, onFloater, speed) 
    if not better_movement.cvars.is_enabled:GetBool() then return end
    if not better_movement.cvars.stop_after_landing:GetBool() then return end

    if ply:OnGround() then
        ply.bm_lerp_value = 0
        ply.bm_lerp_to = better_movement.speed[ply.bm_env_state][ply.bm_walk_state]:GetFloat()
        ply.bm_lerp_from = math.min(ply:GetVelocity():Length() / 4, 300)
    end
end)

timer.Simple(5, function() 
    hook.Add("Think", "bm_remove_setupmove", function() 
        if not better_movement.cvars.remove_weapon_setupmove:GetBool() or not better_movement.cvars.is_enabled:GetBool() then return end
        hook.Remove("SetupMove", "ArcCW_SetupMove")
        hook.Remove("SetupMove", "tfa_setupmove")
        hook.Remove("SetupMove", "ArcticTacRP.SetupMove")
        hook.Remove("SetupMove", "ARC9.SetupMove")
        hook.Remove("Think", "bm_remove_setupmove")
    end)
end)
