better_movement = {}
better_movement.cvars = {}
better_movement.speed = {}

better_movement.cvars.is_enabled = CreateConVar("sv_bm_enabled", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_GAMEDLL}, "Enable the better footsteps thing.")
better_movement.cvars.sst_add = CreateConVar("sv_bm_stepsoundtime_add", 0, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_GAMEDLL}, "Offset for the footstep sound time. (formula: (fMaxSpeed^exp/fMaxSpeed)*mult + offset")
better_movement.cvars.sst_exponent = CreateConVar("sv_bm_stepsoundtime_exponent", 0.6, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_GAMEDLL}, "Exponent for the footstep sound time. (formula: (fMaxSpeed^exp/fMaxSpeed)*mult + offset")
better_movement.cvars.sst_mult = CreateConVar("sv_bm_stepsoundtime_mult", 2600, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_GAMEDLL}, "Multiplier for the footstep sound time. (formula: (fMaxSpeed^exp/fMaxSpeed)*mult + offset")
better_movement.cvars.remove_weapon_setupmove = CreateConVar("sv_bm_remove_weapon_setupmove", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_GAMEDLL}, "Remove all the hooks related to modifying movements from weapon packs. Once removed only restarting the server will return them.")
better_movement.cvars.lerp_speed = CreateConVar("sv_bm_lerp_multiplier", 3, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_GAMEDLL}, "How fast you want to transition between speeds.")
better_movement.cvars.clientside_inertia = CreateConVar("sv_bm_clientside_inertia", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_GAMEDLL}, "Allow some inertia to be calculated and applied clientside.")
better_movement.cvars.cli_lerp = CreateConVar("sv_bm_clientside_inertia_lerp", 8, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_GAMEDLL}, "How fast to lerp between some stuff for inertia.")
better_movement.cvars.force_footsteps = CreateConVar("sv_bm_force_footsteps", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_GAMEDLL}, "Force footsteps to play even if the game thinks you're too slow for it.")
better_movement.cvars.limit_jump_distance = CreateConVar("sv_bm_limit_jump_distance", 4, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_GAMEDLL}, "yea.")
better_movement.cvars.crouch_speed = CreateConVar("sv_bm_crouch_speed", 0.3, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_GAMEDLL}, "yea.")


for env, mult in pairs({["outdoors"] = 1, ["indoors"] = 0.75}) do
    better_movement.speed[env] = {}
    for mv, speed in pairs({["normal"] = 200, ["run"] = 350, ["slow"] = 100}) do
        better_movement.speed[env][mv] = CreateConVar("sv_bm_"..env.."_"..mv, speed * mult, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_GAMEDLL})
    end
end

local function traceable_to_sky(pos, offset)
    local tr = util.TraceLine({start=pos + offset, endpos=pos + Vector(offset.x, offset.y, 100000000), mask=MASK_NPCWORLDSTATIC})
    local temp = util.TraceLine({start=tr.StartPos, endpos=pos, mask=MASK_NPCWORLDSTATIC}) -- doing this because sometimes the trace can go oob and even rarely there are cases where i cant see if it spawned oob
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

hook.Add("SetupMove", "bm_set_env_state", function(ply, mv)
    if not better_movement.cvars.is_enabled:GetBool() then return end

    ply:SetNW2String("bm_env_state_prev", ply:GetNW2String("bm_env_state") or "outdoors")
    ply:SetNW2String("bm_env_state", get_env_state(ply:GetPos()))
end)

hook.Add("SetupMove", "bm_regulate_speed", function(ply, mv)
    if not better_movement.cvars.is_enabled:GetBool() then return end

    ply.bm_walk_state_prev = ply.bm_walk_state or "normal"
    ply.bm_walk_state = "normal"
    if mv:KeyDown(IN_SPEED) then ply.bm_walk_state = "run" end
    if mv:KeyDown(IN_WALK) then ply.bm_walk_state = "slow" end

    local env_state = ply:GetNW2String("bm_env_state")
    local env_state_prev = ply:GetNW2String("bm_env_state_prev")

    if (env_state != env_state_prev or ply.bm_walk_state != ply.bm_walk_state_prev) or ply.bm_first_time == nil then
        ply.bm_lerp_value = 0
        ply.bm_lerp_to = better_movement.speed[env_state][ply.bm_walk_state]:GetFloat()
        ply.bm_lerp_from = ply:GetVelocity():Length()

        ply:SetRunSpeed(better_movement.speed[env_state]["run"]:GetFloat())
        ply:SetWalkSpeed(better_movement.speed[env_state]["normal"]:GetFloat())
        ply:SetSlowWalkSpeed(better_movement.speed[env_state]["slow"]:GetFloat())

        ply.bm_first_time = false
    end

    if IsFirstTimePredicted() then
        ply.bm_lerp_value = math.Clamp((ply.bm_lerp_value or 0) + FrameTime() * better_movement.cvars.lerp_speed:GetFloat(), 0, 1)
    end

    if ply:KeyDown(IN_SPEED) and ply.bm_was_onground != ply:OnGround() and ply:KeyDown(IN_JUMP) and !ply:OnGround() and ply:WaterLevel() < 3 then
        ply:SetVelocity(Vector(-ply:GetVelocity().x/math.max(1,(better_movement.cvars.limit_jump_distance:GetFloat())),-ply:GetVelocity().y/math.max(1,better_movement.cvars.limit_jump_distance:GetFloat()),0))
    end
    ply.bm_was_onground = ply:OnGround()

    local maxspeed = Lerp(ply.bm_lerp_value, ply.bm_lerp_from, ply.bm_lerp_to)

    ply:SetMaxSpeed(maxspeed)

    if ply.bm_walk_state == "run" then
        ply:SetRunSpeed(maxspeed)
    elseif ply.bm_walk_state == "normal" then
        ply:SetWalkSpeed(maxspeed)
    else
        ply:SetSlowWalkSpeed(maxspeed)
    end

    ply:SetDuckSpeed(better_movement.cvars.crouch_speed:GetFloat())
    ply:SetUnDuckSpeed(better_movement.cvars.crouch_speed:GetFloat())
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
