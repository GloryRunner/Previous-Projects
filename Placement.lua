local players = game:GetService("Players")
local run_service = game:GetService("RunService")

local local_player = players.LocalPlayer
local current_camera = workspace.CurrentCamera
local mouse = local_player:GetMouse()

local function get_root_parent(child)
	while child.Parent do
		if child.Parent:IsA("Workspace") then
			return child
		else
			child = child.Parent
		end
	end
	return nil
end

local function get_collision_data(p0, p1, fp, fn)
	local p0x = p0.X
	local p0y = p0.Y
	local p0z = p0.Z

	local p1x = p1.X
	local p1y = p1.Y
	local p1z = p1.Z

	local fpx = fp.X
	local fpy = fp.Y
	local fpz = fp.Z

	local fnx = fn.X
	local fny = fn.Y
	local fnz = fn.Z

	local t = (-fnx * fpx - fny * fpy - fnz * fpz + fnx * p0x + fny * p0y + fnz * p0z) /
		(fnx * p0x + fny * p0y + fnz * p0z - fnx * p1x - fny * p1y - fnz * p1z)

	-- Filter out extraneous solutions
	if t < 0 or t > 1 then
		return {
			is_colliding = false,
			collision_position = nil,
			face_position = fp,
		}
	else
		return {
			is_colliding = true,
			collision_position = p0:Lerp(p1, t),
			face_position = fp
		}

	end
end

local function get_normals(bb_cf, bb_size)
	local bb_pos = bb_cf.Position
	return {
		{
			position = bb_pos - bb_cf.RightVector * (bb_size.X / 2),
			normal = -bb_cf.RightVector
		},
		{
			position = bb_pos + bb_cf.RightVector * (bb_size.X / 2),
			normal = bb_cf.RightVector
		},
		{
			position = bb_pos - bb_cf.UpVector * (bb_size.Y / 2),
			normal = -bb_cf.UpVector
		},
		{
			position = bb_pos + bb_cf.UpVector * (bb_size.Y / 2),
			normal = bb_cf.UpVector
		},
		{
			position = bb_pos - bb_cf.LookVector * (bb_size.Z / 2),
			normal = -bb_cf.LookVector
		},
		{
			position = bb_pos + bb_cf.LookVector * (bb_size.Z / 2),
			normal = bb_cf.LookVector
		}
	}
end

local function update_pos(selected_object)
	local mouse_target = get_root_parent(mouse.Target)

	local target_size
	local target_cf

	if mouse_target:IsA("Model") then
		target_cf, target_size = mouse_target:GetBoundingBox()
	elseif mouse_target:IsA("BasePart") then
		target_size = mouse_target.Size
		target_cf = mouse_target.CFrame
	end

	local p0 = current_camera.CFrame.Position
	local p1 = mouse.Hit.Position
	local face_norms = get_normals(target_cf, target_size) 

	local collisions = {}

	for _, face_data in ipairs(face_norms) do
		local face_normal = face_data.normal
		local face_pos = face_data.position
		local collision_data = get_collision_data(p0, p1, face_pos, face_normal)
		if collision_data.is_colliding then
			table.insert(collisions, {
				collision_position = collision_data.collision_position,
				face_position = collision_data.face_position,
				normal = face_normal
			})
		end
	end


	if #collisions > 0 then
		-- find dist between collision position and face position to determine which one to go for
		local shortest_dist
		local shortest_collision_pos
		local shortest_normal

		for i = 1, #collisions do
			local collision_position = collisions[i].collision_position
			local collision_normal = collisions[i].normal
			local face_pos = collisions[i].face_position
			local distance = (face_pos - collision_position).Magnitude
			if i == 1 or distance < shortest_dist then
				shortest_dist = distance
				shortest_collision_pos = collision_position
				shortest_normal = collision_normal
			end
		end
		
		selected_object:PivotTo(CFrame.new(shortest_collision_pos + shortest_normal))
	end
end
