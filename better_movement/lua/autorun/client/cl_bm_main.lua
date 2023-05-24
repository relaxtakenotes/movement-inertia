if not game.SinglePlayer() then
	hook.Add("PlayerFootstep", "bm_slow_footstep_force_sound", function(ply, pos, foot, soundpath, volume, rf, networked)
		if not better_movement.cvars.force_footsteps:GetBool() then return end

		local speed = ply:GetVelocity():Length()

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