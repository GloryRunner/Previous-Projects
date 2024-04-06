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
