// 2easy to bypass with hackenz
// 2bad

local wish_forward = 0
local wish_side = 0

local sidemove = 0 
local forwardmove = 0

hook.Add("CreateMove", "bm_clientside_inertia", function(cmd)
	if not better_movement.cvars.is_enabled:GetBool() then return end
	if not better_movement.cvars.clientside_inertia:GetBool() then return end
	if LocalPlayer():GetMoveType() == MOVETYPE_NOCLIP then return end

	local maxspeed = LocalPlayer():GetMaxSpeed()

	wish_forward = math.Clamp(cmd:GetForwardMove(), -maxspeed, maxspeed)
	wish_side = math.Clamp(cmd:GetSideMove(), -maxspeed, maxspeed)

	if wish_forward != forwardmove or wish_side != sidemove then
		sidemove = math.Approach(sidemove, wish_side, math.abs(sidemove - wish_side) * FrameTime() * better_movement.cvars.cli_lerp:GetFloat() + 0.001)
		forwardmove = math.Approach(forwardmove, wish_forward, math.abs(forwardmove - wish_forward) * FrameTime() * better_movement.cvars.cli_lerp:GetFloat() + 0.001)
	end

	cmd:SetSideMove(sidemove)
	cmd:SetForwardMove(forwardmove)
end)

if not game.SinglePlayer() then
	hook.Add("PlayerFootstep", "bm_slow_footstep_force_sound", function(ply, pos, foot, soundpath, volume, rf, networked)
		if not better_movement.cvars.force_footsteps:GetBool() then return end

		local speed = ply:GetMaxSpeed()

		if ply:Crouching() then
			should_play = (speed < 60)
		else
			should_play = (speed < 90)
		end

		if should_play then
			ply:EmitSound(soundpath, 75, 100, volume, CHAN_STATIC, 0, 0)
		end
	end)

	net.Receive("bm_player_footstep", function()
		if LocalPlayer():InVehicle() then return end

		if not better_movement.cvars.force_footsteps:GetBool() then return end

		local ply = net.ReadEntity()
		local pos = net.ReadVector()
		local foot = net.ReadInt(1)
		local soundpath = net.ReadString()
		local volume = net.ReadFloat()
		local rf = nil

		hook.Run("PlayerFootstep", ply, ply:GetPos(), foot, soundpath, volume, rf)
	end)
end