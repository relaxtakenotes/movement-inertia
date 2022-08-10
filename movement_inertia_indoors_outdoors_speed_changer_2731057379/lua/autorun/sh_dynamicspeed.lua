print("sh_dynamicspeed loaded")

local clientInMultiplayer = (CLIENT and !game.SinglePlayer())
local serverInMultiplayer = (SERVER and !game.SinglePlayer())

if serverInMultiplayer then util.AddNetworkString("ds_PlayerFootstep") end

CreateConVar("sv_dynamicspeed_indoor_slowwalk", 50, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "How fast will you walk while pressing alt indoors (slowwalking). The default is 50")
CreateConVar("sv_dynamicspeed_indoor_walk", 100, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "How fast will you walk indoors. The default is 100")
CreateConVar("sv_dynamicspeed_indoor_run", 250, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "How fast will you run indoors. The default is 250")
CreateConVar("sv_dynamicspeed_outdoor_slowwalk", 100, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "How fast will you walk while pressing alt outdoors (slowwalking). The default is 100")
CreateConVar("sv_dynamicspeed_outdoor_walk", 150, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "How fast will you walk outdoors. The default is 150")
CreateConVar("sv_dynamicspeed_outdoor_run", 300, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "How fast will you run outdoors. The default is 300")
CreateConVar("sv_dynamicspeed_stepsoundtime_add", 0, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Offset for the footstep sound time. (formula: (fMaxSpeed^exp/fMaxSpeed)*mult + offset")
CreateConVar("sv_dynamicspeed_stepsoundtime_exponent", 0.6, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Exponent for the footstep sound time. (formula: (fMaxSpeed^exp/fMaxSpeed)*mult + offset")
CreateConVar("sv_dynamicspeed_stepsoundtime_mult", 2600, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Multiplier for the footstep sound time. (formula: (fMaxSpeed^exp/fMaxSpeed)*mult + offset")
CreateConVar("sv_dynamicspeed_lerp_multiplier", 10, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "How fast you want to transition between speeds.")
CreateConVar("sv_dynamicspeed_jump_distance", 4, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Some magic number that changes the distance you jump.")
CreateConVar("sv_dynamicspeed_enabled", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Quite obvious, isn't it?")
CreateConVar("sv_dynamicspeed_crouch_speed", 0.3, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Speed for Crouching.")
CreateConVar("sv_dynamicspeed_footstep_workaround", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Enable a workaround for footsteps, which makes them play even if your speed is too low. (under 90 or under 60 when crouched)")

local speeds = {}
speeds["indoors"] = {}
speeds["outdoors"] = {}

local function traceableToSky(pos, offset)
    local tr = util.TraceLine({start=pos + offset, endpos=pos + Vector(offset.x, offset.y, 100000000), mask=MASK_NPCWORLDSTATIC})
	local temp = util.TraceLine({start=tr.StartPos, endpos=pos, mask=MASK_NPCWORLDSTATIC}) -- doing this because sometimes the trace can go oob and even rarely there are cases where i cant see if it spawned oob
    if temp.HitPos == pos and not temp.StartSolid and tr.HitSky then return true end
    return false
end

local function updateSpeed()
	speeds["indoors"]["slowwalk"] = GetConVar("sv_dynamicspeed_indoor_slowwalk"):GetInt()
	speeds["indoors"]["walk"] = GetConVar("sv_dynamicspeed_indoor_walk"):GetInt()
	speeds["indoors"]["run"] = GetConVar("sv_dynamicspeed_indoor_run"):GetInt()
	speeds["outdoors"]["slowwalk"] = GetConVar("sv_dynamicspeed_outdoor_slowwalk"):GetInt()
	speeds["outdoors"]["walk"] = GetConVar("sv_dynamicspeed_outdoor_walk"):GetInt()
	speeds["outdoors"]["run"] = GetConVar("sv_dynamicspeed_outdoor_run"):GetInt()
end

local function getOutdoorsState(pos)
    local tr_1 = traceableToSky(pos, Vector(0,0,0))
    local tr_2 = traceableToSky(pos, Vector(120,0,0))
    local tr_3 = traceableToSky(pos, Vector(0,120,0))
    local tr_4 = traceableToSky(pos, Vector(-120,0,0))
    local tr_5 = traceableToSky(pos, Vector(0,-120,0))
    if (tr_1 or tr_2 or tr_3 or tr_4 or tr_5) then return "outdoors" else return "indoors" end
end

if clientInMultiplayer then
	hook.Add("InitPostEntity", "dynamicspeed_sanity_client", function()
		ply = LocalPlayer()
		updateSpeed()
		ply.ds_lerpFraction = 1
		ply.ds_lerpValue = 1
		ply.ds_posState = getOutdoorsState(ply:GetPos())
		ply.ds_posStatePrevious = ply.ds_posState
		ply.ds_walkState = "walk"
		ply.ds_walkStatePrevious = "walk"
		ply.ds_wasOnGround = true
		ply.ds_lerpTo = speeds[ply.ds_posState][ply.ds_walkState]
		ply.ds_lerpFrom = speeds[ply.ds_posStatePrevious][ply.ds_walkStatePrevious]
		ply.ds_StepTimer = 0
	end)
end

if not clientInMultiplayer then
	hook.Add("PlayerSpawn", "dynamicspeed_sanity", function(ply,transition)
		updateSpeed()
		ply.ds_lerpFraction = 1
		ply.ds_lerpValue = 1
		ply.ds_posState = getOutdoorsState(ply:GetPos())
		ply.ds_posStatePrevious = ply.ds_posState
		ply.ds_walkState = "walk"
		ply.ds_walkStatePrevious = "walk"
		ply.ds_wasOnGround = true
		ply.ds_lerpTo = speeds[ply.ds_posState][ply.ds_walkState]
		ply.ds_lerpFrom = speeds[ply.ds_posStatePrevious][ply.ds_walkStatePrevious]
		ply.ds_StepTimer = 0
	end)
end

hook.Add("SetupMove", "dynamicspeed_think", function(ply,mv)
	if clientInMultiplayer then if ply != LocalPlayer() then return end end
	if GetConVar("sv_dynamicspeed_enabled"):GetInt() != 1 then return end

	local moving = (ply:KeyDown(IN_FORWARD) or ply:KeyDown(IN_BACK) or ply:KeyDown(IN_MOVELEFT) or ply:KeyDown(IN_MOVERIGHT))

	updateSpeed()

	ply.ds_posStatePrevious = ply.ds_posState
	ply.ds_posState = getOutdoorsState(ply:GetPos())

	ply.ds_walkStatePrevious = ply.ds_walkState
	ply.ds_walkState = "walk"
	if ply:KeyDown(IN_SPEED) then ply.ds_walkState = "run" end
	if ply:KeyDown(IN_WALK) then ply.ds_walkState = "slowwalk" end

	if ply.ds_posState != ply.ds_posStatePrevious or ply.ds_walkState != ply.ds_walkStatePrevious then
		ply.ds_lerpValue = 0
		ply.ds_lerpTo = speeds[ply.ds_posState][ply.ds_walkState]
		ply.ds_lerpFrom = ply.ds_actualMaxSpeed
		ply:SetRunSpeed(speeds[ply.ds_posState]["run"])
		ply:SetWalkSpeed(speeds[ply.ds_posState]["walk"])
		ply:SetSlowWalkSpeed(speeds[ply.ds_posState]["slowwalk"])
	end

	ply.ds_lerpValue = math.Clamp(ply.ds_lerpValue + ply.ds_lerpFraction * FrameTime() * GetConVar("sv_dynamicspeed_lerp_multiplier"):GetFloat(), 0, 1)
	local maxspeed = Lerp(ply.ds_lerpValue, ply.ds_lerpFrom, ply.ds_lerpTo)

	if ply:KeyDown(IN_SPEED) and ply.ds_wasOnGround != ply:OnGround() and ply:KeyDown(IN_JUMP) and !ply:OnGround() and ply:WaterLevel() < 3 then
		ply:SetVelocity(Vector(-ply:GetVelocity().x/math.max(1,(GetConVar("sv_dynamicspeed_jump_distance"):GetFloat())),-ply:GetVelocity().y/math.max(1,GetConVar("sv_dynamicspeed_jump_distance"):GetFloat()),0))
	end

	ply.ds_wasOnGround = ply:OnGround()

	mv:SetMaxClientSpeed(maxspeed)

	-- very strangely, to achieve the same effect as just maxclientspeed in singleplayer, i have to do this in multiplayer
	if ply.ds_walkState == "run" then
		ply:SetRunSpeed(maxspeed)
	elseif ply.ds_walkState == "walk" then
		ply:SetWalkSpeed(maxspeed)
	else
		ply:SetSlowWalkSpeed(maxspeed)
	end

	if ply:Crouching() then
		maxspeed = maxspeed * ply:GetCrouchedWalkSpeed()
	end

	ply.ds_actualMaxSpeed = maxspeed 
	ply:SetDuckSpeed(GetConVar("sv_dynamicspeed_crouch_speed"):GetFloat())
	ply:SetUnDuckSpeed(GetConVar("sv_dynamicspeed_crouch_speed"):GetFloat())
end)

if clientInMultiplayer then
	net.Receive("ds_PlayerFootstep", function() 
		-- i dont like this
		local ply = net.ReadEntity()
		local foot = net.ReadInt(1)
		local soundpath = net.ReadString()
		local volume = 0.2
		local rf = nil
		ply:EmitSound(soundpath, 75, 100, volume, CHAN_STATIC, 0, 0)
	end)
end

if serverInMultiplayer then
	hook.Add("PlayerFootstep", "ds_playerfootstephook", function(ply, pos, foot, soundpath, volume, rf)
		if volume < 0.1 then
			net.Start("ds_PlayerFootstep")
			net.WriteEntity(ply)
			net.WriteInt(foot, 1)
			net.WriteString(soundpath)
			net.Send(ply)
		end
	end)
end

hook.Add("SetupMove", "footsteps_play_always", function(ply,mv,cmd)
	if clientInMultiplayer then return end -- playstepsound is serverside only

	if GetConVar("sv_dynamicspeed_footstep_workaround"):GetInt() == 0 then return end

	local shouldPlay = false
	local moving = (ply:KeyDown(IN_FORWARD) or ply:KeyDown(IN_BACK) or ply:KeyDown(IN_MOVELEFT) or ply:KeyDown(IN_MOVERIGHT))
	ply.ds_StepTimer = math.max(ply.ds_StepTimer - 1000 * FrameTime(), 0)

	-- https://github.com/lua9520/source-engine-2018-hl2_src/blob/3bf9df6b2785fa6d951086978a3e66f49427166a/game/shared/baseplayer_shared.cpp#L770
	if ply:Crouching() then
		shouldPlay = (ply.ds_actualMaxSpeed < 60)
	else
		shouldPlay = (ply.ds_actualMaxSpeed < 90)
	end

	if moving and ply:OnGround() and shouldPlay and ply.ds_StepTimer == 0 then
		local fMaxSpeed = ply.ds_actualMaxSpeed + 5
		local exp = GetConVar("sv_dynamicspeed_stepsoundtime_exponent"):GetFloat()
		local mult = GetConVar("sv_dynamicspeed_stepsoundtime_mult"):GetFloat()
		local offset = GetConVar("sv_dynamicspeed_stepsoundtime_add"):GetFloat()
		local fStepTime = (fMaxSpeed^exp/fMaxSpeed)*mult + offset

		if ply:Crouching() then
			fStepTime = fStepTime * ply:GetCrouchedWalkSpeed() + 200
		end

		if serverInMultiplayer then ply:PlayStepSound(0.05) else ply:PlayStepSound(0.2) end

		ply.ds_StepTimer = fStepTime
	end
end)

hook.Add("PlayerStepSoundTime", "dynamicspeed_stepsoundtime", function(ply, iType, bWalking)
	if clientInMultiplayer then if ply != LocalPlayer() then return end end

	local fMaxSpeed = ply.ds_actualMaxSpeed
	local exp = GetConVar("sv_dynamicspeed_stepsoundtime_exponent"):GetFloat()
	local mult = GetConVar("sv_dynamicspeed_stepsoundtime_mult"):GetFloat()
	local offset = GetConVar("sv_dynamicspeed_stepsoundtime_add"):GetFloat()
	local fStepTime = (fMaxSpeed^exp/fMaxSpeed)*mult + offset

	if (iType == STEPSOUNDTIME_ON_LADDER) then
		fStepTime = fStepTime + 100
	elseif (iType == STEPSOUNDTIME_WATER_KNEE) then
		fStepTime = fStepTime + 200
	end

	if (ply:Crouching()) then
		fStepTime = fStepTime + 50
	end

	ply.ds_StepTimer = fStepTime

	return fStepTime
end)

timer.Simple(2, function()
	if GetConVar("sv_dynamicspeed_enabled"):GetInt() != 1 then return end
	hook.Remove("SetupMove", "ArcCW_SetupMove")
	hook.Remove("SetupMove", "tfa_setupmove")
	hook.Remove("SetupMove", "ArcticTacRP.SetupMove")
end)

