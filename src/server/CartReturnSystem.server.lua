-- ServerScriptService.CartReturnSystem
-- REQUIREMENTS (Workspace):
--   Part:  Return_EndTrigger
--   Part:  Return_StartDropoff
--   Model: ReturnSegment   (the LAST physical track piece the cart sits on)
--
-- Optional (better forward accuracy):
--   Part: Return_EndForward   (place slightly "forward" along track direction at the end)
--
-- Optional cart identification:
--   Folder: Workspace.Carts   (put cart models in here) OR set cart Model attribute IsCart=true

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

-- ===== NAMES =====
local END_TRIGGER_NAME = "Return_EndTrigger"
local START_DROPOFF_NAME = "Return_StartDropoff"
local END_SEGMENT_MODEL_NAME = "ReturnSegment"
local END_FORWARD_GUIDE_NAME = "Return_EndForward" -- optional helper part at end

local CARTS_FOLDER_NAME = "Carts" -- optional
local CART_ATTR = "IsCart" -- optional boolean attribute on cart model

-- ===== TUNING =====
local DETACH_FORWARD_STUDS = 14
local DETACH_TIME = 0.45

local RETURN_TIME = 6.0 -- you asked for ~6 seconds
local RISE_AFTER_DROPOFF_STUDS = 10
local RISE_TIME = 1.2

local REPLACEMENT_SPAWN_DELAY = 0.5

local SPINUP_TIME = 4.0
local SPIN_START_RAD_PER_SEC = math.rad(45)
local SPIN_END_RAD_PER_SEC = math.rad(900)
local LAUNCH_START_UP_SPEED = 20
local LAUNCH_END_UP_SPEED = 500
local DELETE_AFTER_SECONDS = 10.0

local POLL_INTERVAL = 0.12

-- ===== BEHAVIOR SWITCHES =====
local DISABLE_COLLISION_ON_MOVING_SEGMENT = true
local DISABLE_COLLISION_ON_CART_DURING_CARRY = false -- set true only if cart snags on scenery

-- ===== INTERNALS =====
local busy = false
local handledCarts = setmetatable({}, { __mode = "k" })

-- ---------- math helpers ----------
local function flatUnit(v: Vector3): Vector3?
	local f = Vector3.new(v.X, 0, v.Z)
	local m = f.Magnitude
	if m < 1e-4 then return nil end
	return f / m
end

local function yawFromLookVector(look: Vector3): number
	local f = flatUnit(look)
	if not f then return 0 end
	-- LookVector points "forward"; yaw 0 when looking at (0,0,-1)
	return math.atan2(-f.X, -f.Z)
end

local function yawFromCFrame(cf: CFrame): number
	return yawFromLookVector(cf.LookVector)
end

local function shortestAngle(a: number, b: number): number
	local diff = (b - a + math.pi) % (2 * math.pi) - math.pi
	return diff
end

local function cfUpright(pos: Vector3, yaw: number): CFrame
	return CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
end

local function moveModelUpright(model: Model, fromPos: Vector3, toPos: Vector3, fromYaw: number, toYaw: number, duration: number)
	local t0 = time()
	local dyaw = shortestAngle(fromYaw, toYaw)

	while true do
		local a = (time() - t0) / duration
		if a >= 1 then break end

		local pos = fromPos:Lerp(toPos, a)
		local yaw = fromYaw + dyaw * a

		model:PivotTo(cfUpright(pos, yaw))
		RunService.Heartbeat:Wait()
	end

	model:PivotTo(cfUpright(toPos, toYaw))
end

-- ---------- general helpers ----------
local function firstBasePart(model: Model): BasePart?
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then return d end
	end
	return nil
end

local function ensurePrimaryPart(model: Model)
	if model.PrimaryPart then return end
	local p = firstBasePart(model)
	if p then model.PrimaryPart = p end
end

local function setAnchored(model: Model, anchored: boolean)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = anchored
		end
	end
end

local function setCanCollide(model: Model, canCollide: boolean)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = canCollide
		end
	end
end

local function zeroVelocity(model: Model)
	ensurePrimaryPart(model)
	if model.PrimaryPart then
		model.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
		model.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
	end
end

local function destroyExternalConstraints(model: Model)
	-- Prevent dragging the map: remove welds/constraints that connect outside this model
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("WeldConstraint") then
			local p0, p1 = d.Part0, d.Part1
			if (p0 and not p0:IsDescendantOf(model)) or (p1 and not p1:IsDescendantOf(model)) then
				d:Destroy()
			end
		end
	end
end

local function findCartModelFromHit(hit: Instance): Model?
	if not hit then return nil end

	local cartsFolder = workspace:FindFirstChild(CARTS_FOLDER_NAME)

	local node = hit
	while node and node ~= workspace do
		if node:IsA("Model") then
			if cartsFolder and node:IsDescendantOf(cartsFolder) then
				return node
			end
			if node:GetAttribute(CART_ATTR) == true then
				return node
			end

			local nameLower = string.lower(node.Name)
			if string.find(nameLower, "cart") then
				return node
			end

			for _, d in ipairs(node:GetDescendants()) do
				if d:IsA("VehicleSeat") or d:IsA("Seat") then
					return node
				end
			end
		end
		node = node.Parent
	end

	return nil
end

local function getActiveEndSegment(): Model?
	local seg = workspace:FindFirstChild(END_SEGMENT_MODEL_NAME)
	if seg and seg:IsA("Model") then return seg end
	return nil
end

local function ensureSegmentTemplate(segment: Model): Model
	local existing = ServerStorage:FindFirstChild("ReturnSegmentTemplate_Internal")
	if existing and existing:IsA("Model") then
		return existing
	end

	local clone = segment:Clone()
	clone.Name = "ReturnSegmentTemplate_Internal"

	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
			d:Destroy()
		end
	end

	clone.Parent = ServerStorage
	return clone
end

local function spawnReplacement(template: Model, endCF: CFrame)
	if getActiveEndSegment() then return end

	local repl = template:Clone()
	repl.Name = END_SEGMENT_MODEL_NAME
	repl.Parent = workspace
	ensurePrimaryPart(repl)

	setAnchored(repl, true)
	repl:PivotTo(endCF)

	setCanCollide(repl, true)
	destroyExternalConstraints(repl)
end

local function weldCartToSegment(cart: Model, segment: Model): WeldConstraint
	ensurePrimaryPart(cart)
	ensurePrimaryPart(segment)
	assert(cart.PrimaryPart, "Cart has no PrimaryPart/BasePart")
	assert(segment.PrimaryPart, "ReturnSegment has no PrimaryPart/BasePart")

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = segment.PrimaryPart
	weld.Part1 = cart.PrimaryPart
	weld.Parent = segment.PrimaryPart
	return weld
end

local function setNetworkOwnerServerSafe(model: Model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			if not d.Anchored then
				pcall(function()
					d:SetNetworkOwner(nil)
				end)
			end
		end
	end
end

local function releaseCart(cart: Model, weld: WeldConstraint?)
	if weld and weld.Parent then weld:Destroy() end
	zeroVelocity(cart)
	setAnchored(cart, false)
end

-- Direction chooser (fixes "detaches left instead of forward")
local function getForwardDir(cart: Model, segment: Model): Vector3
	local guide = workspace:FindFirstChild(END_FORWARD_GUIDE_NAME)
	if guide and guide:IsA("BasePart") then
		local dir = flatUnit(guide.Position - segment:GetPivot().Position)
		if dir then return dir end
	end

	ensurePrimaryPart(cart)
	if cart.PrimaryPart then
		local v = flatUnit(cart.PrimaryPart.AssemblyLinearVelocity)
		if v then return v end

		local l = flatUnit(cart.PrimaryPart.CFrame.LookVector)
		if l then return l end
	end

	local s = flatUnit(segment:GetPivot().LookVector)
	if s then return s end

	return Vector3.new(0, 0, -1)
end

-- ---------- main ----------
local endTrigger = workspace:FindFirstChild(END_TRIGGER_NAME)
assert(endTrigger and endTrigger:IsA("BasePart"), "Missing Workspace." .. END_TRIGGER_NAME)

local startDropoff = workspace:FindFirstChild(START_DROPOFF_NAME)
assert(startDropoff and startDropoff:IsA("BasePart"), "Missing Workspace." .. START_DROPOFF_NAME)

endTrigger.CanCollide = false
endTrigger.CanTouch = true
endTrigger.CanQuery = true
endTrigger.Transparency = 1

local function cartReturnSequence(cart: Model)
	if busy then return end
	if handledCarts[cart] then return end
	handledCarts[cart] = true

	local segment = getActiveEndSegment()
	if not segment then
		warn("ReturnSegment not found. Your last track piece must be a Model named: " .. END_SEGMENT_MODEL_NAME)
		handledCarts[cart] = nil
		return
	end

	busy = true

	ensurePrimaryPart(segment)
	ensurePrimaryPart(cart)
	if not segment.PrimaryPart or not cart.PrimaryPart then
		warn("Missing PrimaryPart on ReturnSegment or Cart")
		handledCarts[cart] = nil
		busy = false
		return
	end

	-- Prevent dragging map
	destroyExternalConstraints(segment)

	-- Snapshot end piece transform for replacement
	local endCF = segment:GetPivot()
	local template = ensureSegmentTemplate(segment)

	-- Decide "forward" using guide/velocity/look
	local forwardDir = getForwardDir(cart, segment)

	-- Server owns cart physics (segment is anchored so we don't set ownership on it)
	setNetworkOwnerServerSafe(cart)

	-- Cart must be unanchored to move with weld (no teleport)
	zeroVelocity(cart)
	setAnchored(cart, false)

	if DISABLE_COLLISION_ON_CART_DURING_CARRY then
		setCanCollide(cart, false)
	end

	-- Weld in-place (no snapping)
	local weld = weldCartToSegment(cart, segment)

	-- Build a yaw-only relative transform (avoids pitch/roll issues)
	local segCF0 = segment:GetPivot()
	local cartCF0 = cart:GetPivot()

	local relPos = segCF0:PointToObjectSpace(cartCF0.Position)
	local yawSeg0 = yawFromCFrame(segCF0)
	local yawCart0 = yawFromCFrame(cartCF0)
	local yawOffset = yawCart0 - yawSeg0

	local relCF = CFrame.new(relPos) * CFrame.Angles(0, yawOffset, 0)

	-- Segment stays anchored; we move it with PivotTo
	setAnchored(segment, true)

	if DISABLE_COLLISION_ON_MOVING_SEGMENT then
		setCanCollide(segment, false)
	end

	-- Rename moving segment so replacement can use the real name
	segment.Name = END_SEGMENT_MODEL_NAME .. "_Moving"

	-- 1) DETACH: move forward (upright, no rotation change)
	local fromPos = segCF0.Position
	local detachPos = fromPos + (forwardDir * DETACH_FORWARD_STUDS)
	local yawDetach = yawSeg0
	moveModelUpright(segment, fromPos, detachPos, yawSeg0, yawDetach, DETACH_TIME)

	-- Spawn replacement after short delay
	task.delay(REPLACEMENT_SPAWN_DELAY, function()
		spawnReplacement(template, endCF)
	end)

	-- 2) RETURN: over 6s, move to start while smoothly yawing ~180 (upright)
	-- You asked: "slowly turn 180 degrees towards the beginning while making its way there"
	local startPos = startDropoff.Position

	-- Face "towards beginning" = opposite of forwardDir (180 turn)
	local backDir = flatUnit(-forwardDir) or Vector3.new(0, 0, 1)
	local cartTargetYaw = yawFromLookVector(backDir)

	-- Target cart CFrame (upright)
	local cartTargetCF = cfUpright(startPos, cartTargetYaw)

	-- Solve segment target that puts cart exactly there (no teleport)
	local segmentTargetCF = cartTargetCF * relCF:Inverse()

	-- Move segment upright to that solved target
	local returnFromPos = segment:GetPivot().Position
	local returnToPos = segmentTargetCF.Position

	local returnFromYaw = yawFromCFrame(segment:GetPivot())
	local returnToYaw = yawFromCFrame(segmentTargetCF)

	moveModelUpright(segment, returnFromPos, returnToPos, returnFromYaw, returnToYaw, RETURN_TIME)

	-- Drop cart (no teleport)
	releaseCart(cart, weld)

	if DISABLE_COLLISION_ON_CART_DURING_CARRY then
		setCanCollide(cart, true)
	end

	-- 3) RISE: straight up 10 studs (upright)
	local riseFromPos = segment:GetPivot().Position
	local riseToPos = riseFromPos + Vector3.new(0, RISE_AFTER_DROPOFF_STUDS, 0)
	local riseYaw = yawFromCFrame(segment:GetPivot())
	moveModelUpright(segment, riseFromPos, riseToPos, riseYaw, riseYaw, RISE_TIME)

	-- 4) SPIN + LAUNCH: WORLD-UP, not local-up (fixes "launches forward")
	local launchStart = time()
	local last = time()

	local curPos = segment:GetPivot().Position
	local curYaw = yawFromCFrame(segment:GetPivot())

	while true do
		local now = time()
		local dt = now - last
		last = now

		local t = (now - launchStart) / SPINUP_TIME
		if t > 1 then t = 1 end

		local spinRate = SPIN_START_RAD_PER_SEC + (SPIN_END_RAD_PER_SEC - SPIN_START_RAD_PER_SEC) * t
		local upSpeed = LAUNCH_START_UP_SPEED + (LAUNCH_END_UP_SPEED - LAUNCH_START_UP_SPEED) * t

		curYaw += spinRate * dt
		curPos += Vector3.new(0, upSpeed * dt, 0) -- WORLD UP

		segment:PivotTo(cfUpright(curPos, curYaw))

		if (now - launchStart) >= DELETE_AFTER_SECONDS then
			break
		end

		RunService.Heartbeat:Wait()
	end

	if segment and segment.Parent then
		segment:Destroy()
	end

	handledCarts[cart] = nil
	busy = false
end

-- Detection (Touched + overlap fallback)
endTrigger.Touched:Connect(function(hit)
	local cart = findCartModelFromHit(hit)
	if cart then
		task.spawn(cartReturnSequence, cart)
	end
end)

task.spawn(function()
	while true do
		task.wait(POLL_INTERVAL)
		if busy then continue end

		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = {}

		local parts = workspace:GetPartBoundsInBox(endTrigger.CFrame, endTrigger.Size, overlap)
		for _, p in ipairs(parts) do
			local cart = findCartModelFromHit(p)
			if cart then
				task.spawn(cartReturnSequence, cart)
				break
			end
		end
	end
end)
