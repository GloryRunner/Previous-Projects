local physics = {}

function physics.get_projectile_pos(p_i, p_f, t_total, t_into)
    local f_grav = Vector3.new(0, -workspace.Gravity, 0)
	local t_total_sqrd = t_total * t_total
	local t_into_sqrd = t_into * t_into
	local v0 = (p_f - p_i - (1 / 2) * f_grav * t_total_sqrd) / t_total
	return (1 / 2) * f_grav * t_into_sqrd + v0 * t_into + p_i
end

function physics.get_aligned_cf(p_i, p_f, t_total, t_into)
    local current_pos = physics.get_projectile_pos(p_i, p_f, t_total, t_into)
    local next_pos = physics.get_projectile_pos(p_i, p_f, t_total, t_into + 0.1)
    local dir = (current_pos - next_pos).Unit
    return CFrame.lookAlong(current_pos, dir)
end

function physics.get_t_total(p_i, p_f)
	-- Scales projectile time according to distance from target
	local distance = (p_f - p_i).Magnitude
	return distance / 300
end

return physics
