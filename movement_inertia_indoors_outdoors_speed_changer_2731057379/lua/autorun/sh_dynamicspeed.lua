print("sh_dynamicspeed loaded")

local clientInMultiplayer = (CLIENT and !game.SinglePlayer())

CreateConVar("sv_dynamicspeed_indoor_slowwalk", 50, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "How fast will you walk while pressing alt indoors (slowwalking). The default is 50")
CreateConVar("sv_dynamicspeed_indoor_walk", 100, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "How fast will you walk indoors. The default is 100")
CreateConVar("sv_dynamicspeed_indoor_run", 250, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "How fast will you run indoors. The default is 250")
CreateConVar("sv_dynamicspeed_outdoor_slowwalk", 100, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "How fast will you walk while pressing alt outdoors (slowwalking). The default is 100")
CreateConVar("sv_dynamicspeed_outdoor_walk", 150, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "How fast will you walk outdoors. The default is 150")
CreateConVar("sv_dynamicspeed_outdoor_run", 300, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "How fast will you run outdoors. The default is 300")
CreateConVar("sv_dynamicspeed_stepsoundtime_offset", 110, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Offset for the footstep sound time. The default is 100")
CreateConVar("sv_dynamicspeed_stepsoundtime_multiplier", 40000, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Multiplier for the footstep sound time. The default is 40000 (needed due to the way i calculate stepsoundtime)")
CreateConVar("sv_dynamicspeed_lerp_multiplier", 10, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "How fast you want to transition between speeds.")
CreateConVar("sv_dynamicspeed_jump_distance", 4, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Some magic number that changes the distance you jump.")
CreateConVar("sv_dynamicspeed_enabled", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Quite obvious, isn't it?")

local speeds = {}
speeds["indoors"] = {}
speeds["outdoors"] = {}

speeds["indoors"]["slowwalk"] = GetConVar("sv_dynamicspeed_indoor_slowwalk"):GetInt()
speeds["indoors"]["walk"] = GetConVar("sv_dynamicspeed_indoor_walk"):GetInt()
speeds["indoors"]["run"] = GetConVar("sv_dynamicspeed_indoor_run"):GetInt()
speeds["outdoors"]["slowwalk"] = GetConVar("sv_dynamicspeed_outdoor_slowwalk"):GetInt()
speeds["outdoors"]["walk"] = GetConVar("sv_dynamicspeed_outdoor_walk"):GetInt()
speeds["outdoors"]["run"] = GetConVar("sv_dynamicspeed_outdoor_run"):GetInt()

local function traceableToSky(pos, offset)
    local tr = util.TraceLine({start=pos + offset, endpos=pos + Vector(offset.x, offset.y, 100000000), mask=MASK_NPCWORLDSTATIC})
	local temp = util.TraceLine({start=tr.StartPos, endpos=pos, mask=MASK_NPCWORLDSTATIC}) -- doing this because sometimes the trace can go oob and even rarely there are cases where i cant see if it spawned oob
    if temp.HitPos == pos and tr.HitSky then return true end
    return false
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
		ply.ds_lerpFraction = 1
		ply.ds_lerpValue = 1
		ply.ds_lerpFrom = 0
		ply.ds_lerpTo = 0
		ply.ds_posState = "indoors"
		ply.ds_posStatePrevious = "indoors"
		ply.ds_walkState = "walk"
		ply.ds_walkStatePrevious = "walk"
		ply.ds_wasOnGround = true
	end)
end

if not clientInMultiplayer then
	hook.Add("PlayerSpawn", "dynamicspeed_sanity", function(ply,transition)
		ply.ds_lerpFraction = 1
		ply.ds_lerpValue = 1
		ply.ds_lerpFrom = 0
		ply.ds_lerpTo = 0
		ply.ds_posState = "indoors"
		ply.ds_posStatePrevious = "indoors"
		ply.ds_walkState = "walk"
		ply.ds_walkStatePrevious = "walk"
		ply.ds_wasOnGround = true
	end)
end

hook.Add("SetupMove", "dynamicspeed_think", function(ply,mv)
	if clientInMultiplayer then if ply != LocalPlayer() then return end end
	if GetConVar("sv_dynamicspeed_enabled"):GetInt() != 1 then return end

	ply.ds_posStatePrevious = ply.ds_posState
	ply.ds_posState = getOutdoorsState(ply:GetPos())

	ply.ds_walkStatePrevious = ply.ds_walkState
	ply.ds_walkState = "walk"
	if ply:KeyDown(IN_SPEED) then ply.ds_walkState = "run" end
	if ply:KeyDown(IN_WALK) then ply.ds_walkState = "slowwalk" end

	if ply.ds_posState != ply.ds_posStatePrevious or ply.ds_walkState != ply.ds_walkStatePrevious then
		if ply.ds_lerpValue == 1 then ply.ds_lerpValue = 0 else ply.ds_lerpValue = 1 - ply.ds_lerpValue end
		ply.ds_lerpTo = speeds[ply.ds_posState][ply.ds_walkState]
		ply.ds_lerpFrom = speeds[ply.ds_posStatePrevious][ply.ds_walkStatePrevious]
		ply:SetRunSpeed(speeds[ply.ds_posState]["run"])
		ply:SetWalkSpeed(speeds[ply.ds_posState]["walk"])
		ply:SetSlowWalkSpeed(speeds[ply.ds_posState]["slowwalk"])
	end

	local maxspeed = Lerp(ply.ds_lerpValue, ply.ds_lerpFrom, ply.ds_lerpTo)
	ply.ds_lerpValue = math.Clamp(ply.ds_lerpValue + ply.ds_lerpFraction * FrameTime() * GetConVar("sv_dynamicspeed_lerp_multiplier"):GetFloat(), 0, 1)

	if not ply:KeyDown(IN_FORWARD) and not ply:KeyDown(IN_BACK) and not ply:KeyDown(IN_MOVELEFT) and not ply:KeyDown(IN_MOVERIGHT) then
		if ply.ds_lerpTo < ply.ds_lerpFrom then ply.ds_lerpValue = 1 end
		if ply.ds_lerpTo > ply.ds_lerpFrom then ply.ds_lerpValue = 0 end
	end

	if ply:KeyDown(IN_SPEED) and ply.ds_wasOnGround != ply:OnGround() and !ply:OnGround() and ply:WaterLevel() < 3 then
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

	ply.ds_actualMaxSpeed = maxspeed
	ply:SetDuckSpeed(0.3)
	ply:SetUnDuckSpeed(0.3)
end)

hook.Add("PlayerStepSoundTime", "dynamicspeed_stepsoundtime", function(ply, iType, bWalking)
	if clientInMultiplayer then if ply != LocalPlayer() then return end end

	local fMaxSpeed = ply.ds_actualMaxSpeed
	local fStepTime = (1/fMaxSpeed)*GetConVar("sv_dynamicspeed_stepsoundtime_multiplier"):GetInt() + GetConVar("sv_dynamicspeed_stepsoundtime_offset"):GetInt()

	if (iType == STEPSOUNDTIME_ON_LADDER) then
		fStepTime = fStepTime + 100
	elseif (iType == STEPSOUNDTIME_WATER_KNEE) then
		fStepTime = fStepTime + 200
	end

	if (ply:Crouching()) then
		fStepTime = fStepTime + 50
	end

	return fStepTime
end)

timer.Simple(2, function()
	if GetConVar("sv_dynamicspeed_enabled"):GetInt() != 1 then return end
	hook.Remove("SetupMove", "ArcCW_SetupMove")
	hook.Remove("SetupMove", "tfa_setupmove")
	hook.Remove("SetupMove", "ArcticTacRP.SetupMove")
end)

