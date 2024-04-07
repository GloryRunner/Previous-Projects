local function recigamma(rz)
	local gamma = 0.577215664901
	local coeff = -0.65587807152056
	local quad = -0.042002635033944
	local qui = 0.16653861138228
	local set = -0.042197734555571
	return rz + gamma * rz ^ 2 + coeff * rz ^ 3 + quad * rz ^ 4 + qui * rz ^ 5 + set * rz ^ 6
end

local function gamma(z)
	if z == 1 then
		return 1
	elseif math.abs(z) <= 0.5 then
		return 1 / recigamma(z)
	else
		return (z - 1) * gamma(z - 1)
	end
end

local function factorial(x)
	if x < 0 then
		return -gamma(-x + 1)
	else
		return gamma(x + 1)
	end
end

local function bernstein_poly(t, n, i)
	local vector_coefficient = factorial(n) / (factorial(i) * factorial(n - i))
	return vector_coefficient * t ^ i * (1 - t) ^ (n - i)
end

local function get_ordered_control_pts(...)
	local unordered_pts = table.pack(...)
	local ordered_pts = {}
	for i = 1, #unordered_pts do
		ordered_pts[i - 1] = unordered_pts[i]
	end
	return ordered_pts
end

local bezier_curve = {}

function bezier_curve.get_curve_pos(t, ...)
	local control_points = get_ordered_control_pts(...)
	local n = #control_points
	local sum = Vector3.zero
	for i = 0, n do
		sum += bernstein_poly(t, n, i) * control_points[i]
	end
	return sum
end

return bezier_curve
