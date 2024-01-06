local function rad_to_deg(x)
	local conversion_factor = 360 / (2 * math.pi)
	return conversion_factor * x
end

local function deg_to_rad(x)
	local conversion_factor = (2 * math.pi) / 360
	return conversion_factor * x
end

local function dot(v0, v1)
	return (v0.X * v1.X) + (v0.Y * v1.Y) + (v0.Z * v1.Z)
end

local function get_magnitude(v)
	return math.sqrt((v.X * v.X) + (v.Y * v.Y) + (v.Z * v.Z))
end

local function get_normalized_vec(v)
	local v_mag = get_magnitude(v)
	local vn_x = v.X / v_mag
	local vn_y = v.Y / v_mag
	local vn_z = v.Z / v_mag
	return Vector3.new(vn_x, vn_y, vn_z)
end

local function get_theta(v0, v1)
	local v0_norm = get_normalized_vec(v0)
	local projection_len = dot(v0_norm, v1)
	local v1_mag = get_magnitude(v1)
	return rad_to_deg(math.acos(projection_len / v1_mag))
end
