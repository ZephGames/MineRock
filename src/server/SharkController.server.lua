-- ServerScriptService.SharkController
-- Makes tagged shark models swim along the water surface with obstacle avoidance.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SHARK_TAG = "Shark"
local SWIM_SPEED = 35
local TURN_RATE = math.rad(45)
local DRIFT_INTERVAL = 3
local AVOID_DISTANCE = 25
local SIDE_CHECK_ANGLE = math.rad(35)
local STUCK_CHECK_INTERVAL = 4
local MIN_MOVEMENT_SQ = 4 -- 2 studs of movement squared
local HEIGHT_ADJUST_SPEED = 6
local PLAYER_DETECTION_RANGE = 175
local PLAYER_LOSE_RANGE = 200
local ATTACK_DISTANCE = 6
local TARGET_REFRESH_INTERVAL = 0.4

local function randomHorizontalUnit()
    local theta = math.random() * math.pi * 2
    return Vector3.new(math.cos(theta), 0, math.sin(theta))
end

local function rotateY(vector, angle)
    local cf = CFrame.Angles(0, angle, 0)
    local rotated = cf:VectorToWorldSpace(vector)
    return Vector3.new(rotated.X, 0, rotated.Z)
end

local function findRoot(model)
    if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
        return model.PrimaryPart
    end

    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            return descendant
        end
    end
end

local function ensureMover(instance, className, name, props)
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

local function createState(model)
    local root = findRoot(model)
    if not root then
        return
    end

    root.Anchored = false

    local bodyVelocity = ensureMover(root, "BodyVelocity", "SharkBodyVelocity", {
        MaxForce = Vector3.new(1e6, 1e6, 1e6),
        P = 1e4,
        Velocity = Vector3.new(),
    })

    local bodyGyro = ensureMover(root, "BodyGyro", "SharkBodyGyro", {
        MaxTorque = Vector3.new(1e6, 1e6, 1e6),
        P = 2e4,
        CFrame = root.CFrame,
    })

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = { model }

    return {
        model = model,
        root = root,
        bodyVelocity = bodyVelocity,
        bodyGyro = bodyGyro,
        raycastParams = raycastParams,
        direction = randomHorizontalUnit(),
        targetHeight = model:GetAttribute("WaterHeight") or root.Position.Y,
        driftTimer = 0,
        stuckTimer = 0,
        lastPosition = root.Position,
        target = nil,
        targetTimer = 0,
    }
end

local function isSwimming(humanoid)
    if not humanoid then
        return false
    end

    local state = humanoid:GetState()
    return state == Enum.HumanoidStateType.Swimming
end

local function findPlayerTarget(state)
    local best
    local bestDistSq = PLAYER_DETECTION_RANGE * PLAYER_DETECTION_RANGE

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if not character then
            continue
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not root or humanoid.Health <= 0 then
            continue
        end

        if not isSwimming(humanoid) then
            continue
        end

        local offset = root.Position - state.root.Position
        local distSq = offset:Dot(offset)
        if distSq <= bestDistSq then
            bestDistSq = distSq
            best = {
                humanoid = humanoid,
                root = root,
            }
        end
    end

    return best
end

local function updateTarget(state, dt)
    state.targetTimer += dt
    if state.targetTimer < TARGET_REFRESH_INTERVAL then
        return state.target
    end

    state.targetTimer = 0
    local target = state.target

    if target then
        local humanoid = target.humanoid
        local root = target.root
        local valid = humanoid
            and root
            and humanoid.Health > 0
            and root.Parent
            and isSwimming(humanoid)

        if valid then
            local offset = root.Position - state.root.Position
            local distSq = offset:Dot(offset)
            if distSq <= PLAYER_LOSE_RANGE * PLAYER_LOSE_RANGE then
                return target
            end
        end
    end

    state.target = findPlayerTarget(state)
    return state.target
end

local function adjustDirectionFromHit(state, hitResult)
    local normal = hitResult.Normal
    local incoming = state.direction
    local reflected = incoming - 2 * incoming:Dot(normal) * normal
    reflected = Vector3.new(reflected.X, 0, reflected.Z)

    if reflected.Magnitude < 0.1 then
        reflected = randomHorizontalUnit()
    else
        reflected = reflected.Unit
    end

    state.direction = reflected
end

local function checkObstacles(state)
    local root = state.root
    local direction = state.direction

    local forwardResult = workspace:Raycast(root.Position, direction * AVOID_DISTANCE, state.raycastParams)
    if forwardResult then
        adjustDirectionFromHit(state, forwardResult)
        return
    end

    local leftDir = rotateY(direction, SIDE_CHECK_ANGLE)
    local rightDir = rotateY(direction, -SIDE_CHECK_ANGLE)

    local leftHit = workspace:Raycast(root.Position, leftDir * (AVOID_DISTANCE * 0.6), state.raycastParams)
    local rightHit = workspace:Raycast(root.Position, rightDir * (AVOID_DISTANCE * 0.6), state.raycastParams)

    if leftHit and rightHit then
        if leftHit.Distance < rightHit.Distance then
            state.direction = rotateY(direction, -TURN_RATE)
        else
            state.direction = rotateY(direction, TURN_RATE)
        end
    elseif leftHit then
        state.direction = rotateY(direction, -TURN_RATE)
    elseif rightHit then
        state.direction = rotateY(direction, TURN_RATE)
    end
end

local function updateShark(state, dt)
    if not state.root.Parent then
        return false
    end

    local target = updateTarget(state, dt)
    if target then
        local toTarget = target.root.Position - state.root.Position
        local planarToTarget = Vector3.new(toTarget.X, 0, toTarget.Z)

        if planarToTarget.Magnitude > 0.1 then
            state.direction = planarToTarget.Unit
        end

        state.driftTimer = 0
    end

    checkObstacles(state)

    state.driftTimer += dt
    if not target and state.driftTimer >= DRIFT_INTERVAL then
        local driftAngle = math.random(-10, 10)
        state.direction = rotateY(state.direction, math.rad(driftAngle)).Unit
        state.driftTimer = 0
    end

    local rootPosition = state.root.Position
    local delta = rootPosition - state.lastPosition
    if delta:Dot(delta) < MIN_MOVEMENT_SQ then
        state.stuckTimer += dt
        if state.stuckTimer >= STUCK_CHECK_INTERVAL then
            state.direction = rotateY(randomHorizontalUnit(), math.rad(math.random(-45, 45))).Unit
            state.stuckTimer = 0
        end
    else
        state.stuckTimer = 0
        state.lastPosition = rootPosition
    end

    local planarDir = Vector3.new(state.direction.X, 0, state.direction.Z)
    if planarDir.Magnitude < 0.1 then
        planarDir = randomHorizontalUnit()
    end
    planarDir = planarDir.Unit

    local verticalDelta = state.targetHeight - rootPosition.Y
    local verticalSpeed = math.clamp(verticalDelta * HEIGHT_ADJUST_SPEED, -SWIM_SPEED, SWIM_SPEED)

    state.bodyVelocity.Velocity = Vector3.new(planarDir.X, 0, planarDir.Z) * SWIM_SPEED + Vector3.new(0, verticalSpeed, 0)

    local lookPoint = rootPosition + planarDir
    state.bodyGyro.CFrame = CFrame.new(rootPosition, lookPoint)

    if target then
        local offset = target.root.Position - rootPosition
        local distSq = offset:Dot(offset)
        if distSq <= ATTACK_DISTANCE * ATTACK_DISTANCE then
            target.humanoid.Health = 0
            state.target = nil
        end
    end

    return true
end

local function trackShark(model)
    if model:GetAttribute("SharkControllerSetup") then
        return
    end
    model:SetAttribute("SharkControllerSetup", true)

    local state = createState(model)
    if not state then
        return
    end

    local heartbeatConnection
    local ancestryConnection

    heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
        if not updateShark(state, dt) then
            if heartbeatConnection then
                heartbeatConnection:Disconnect()
                heartbeatConnection = nil
            end
        end
    end)

    ancestryConnection = model.AncestryChanged:Connect(function(_, parent)
        if parent then
            return
        end

        if heartbeatConnection then
            heartbeatConnection:Disconnect()
            heartbeatConnection = nil
        end

        if ancestryConnection then
            ancestryConnection:Disconnect()
            ancestryConnection = nil
        end
    end)
end

for _, model in ipairs(CollectionService:GetTagged(SHARK_TAG)) do
    trackShark(model)
end

CollectionService:GetInstanceAddedSignal(SHARK_TAG):Connect(trackShark)
