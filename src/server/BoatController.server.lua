-- ServerScriptService.BoatController
-- Makes tagged boats drivable using VehicleSeat input.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local BOAT_TAG = "DriveableBoat"
local MAX_SPEED = 80
local TURN_RATE = math.rad(70)
local MAX_FORCE = Vector3.new(2e6, 0, 2e6)
-- Apply torque on all axes so the boat resists tipping over while still rotating on Y for steering.
local MAX_TORQUE = Vector3.new(5e6, 5e6, 5e6)

local function findSeat(model)
for _, descendant in ipairs(model:GetDescendants()) do
if descendant:IsA("VehicleSeat") then
return descendant
end
end
end

local function getPrimaryPart(model)
if model.PrimaryPart then
return model.PrimaryPart
end

for _, descendant in ipairs(model:GetDescendants()) do
if descendant:IsA("BasePart") then
return descendant
end
end
end

local function createMover(instance, className, name, props)
local existing = instance:FindFirstChild(name)
if existing and existing:IsA(className) then
return existing
end

local mover = Instance.new(className)
mover.Name = name

for propName, propValue in pairs(props) do
mover[propName] = propValue
end

mover.Parent = instance
return mover
end

local function setupBoat(model)
if model:GetAttribute("BoatControllerSetup") then
return
end
model:SetAttribute("BoatControllerSetup", true)

local seat = findSeat(model)
local root = getPrimaryPart(model)
if not seat or not root then
return
end

root.Anchored = false

local bodyVelocity = createMover(root, "BodyVelocity", "BoatBodyVelocity", {
MaxForce = MAX_FORCE,
P = 2e4,
Velocity = Vector3.new(),
})

local bodyGyro = createMover(root, "BodyGyro", "BoatBodyGyro", {
    MaxTorque = MAX_TORQUE,
    P = 2e5,
    D = 1e3,
    CFrame = root.CFrame,
})

local driveConnection
local occupantConnection
local ancestryConnection

local function stopDriving()
if driveConnection then
driveConnection:Disconnect()
driveConnection = nil
end

bodyVelocity.Velocity = Vector3.new()
bodyGyro.CFrame = root.CFrame
end

local function startDriving()
if driveConnection then
driveConnection:Disconnect()
end

driveConnection = RunService.Heartbeat:Connect(function(dt)
if not seat.Parent or not root.Parent then
stopDriving()
return
end

local throttle = math.clamp(seat.Throttle, -1, 1)
local steer = math.clamp(seat.Steer, -1, 1)

local forward = root.CFrame.LookVector
local planarForward = Vector3.new(forward.X, 0, forward.Z)
if planarForward.Magnitude > 0 then
planarForward = planarForward.Unit
end

local targetVelocity = planarForward * (throttle * MAX_SPEED)
local currentY = root.AssemblyLinearVelocity.Y

bodyVelocity.Velocity = Vector3.new(targetVelocity.X, currentY, targetVelocity.Z)

        local _, yaw, _ = root.CFrame:ToEulerAnglesYXZ()
        local newYaw = yaw + steer * TURN_RATE * dt

        -- Keep the boat upright by forcing zero roll/pitch while allowing yaw steering.
        bodyGyro.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, newYaw, 0)
    end)
end

occupantConnection = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
if seat.Occupant then
startDriving()
else
stopDriving()
end
end)

ancestryConnection = model.AncestryChanged:Connect(function(_, parent)
if parent then
return
end

stopDriving()

if occupantConnection then
occupantConnection:Disconnect()
occupantConnection = nil
end

if ancestryConnection then
ancestryConnection:Disconnect()
ancestryConnection = nil
end
end)

if seat.Occupant then
startDriving()
end
end

for _, model in ipairs(CollectionService:GetTagged(BOAT_TAG)) do
setupBoat(model)
end

CollectionService:GetInstanceAddedSignal(BOAT_TAG):Connect(setupBoat)
