-- ModuleScript (Rojo): ReplicatedStorage > RojoShared > PickaxeClient
-- Real pickaxe client logic lives here.
-- A tiny Tool LocalScript will call: PickaxeClient.init(tool)

local PickaxeClient = {}

function PickaxeClient.init(tool)
  local Players = game:GetService("Players")
  local ReplicatedStorage = game:GetService("ReplicatedStorage")
  local Shared = ReplicatedStorage:WaitForChild("RojoShared")
  local Workspace = game:GetService("Workspace")
  local MarketplaceService = game:GetService("MarketplaceService")
  local RunService = game:GetService("RunService")

  local player = Players.LocalPlayer
  local character
  local mouse

  -- If your PickaxeConfig is in ReplicatedStorage root, keep this line:
  local PickaxeConfig = require(Shared:WaitForChild("PickaxeConfig"))
  local OreConfig = require(Shared:WaitForChild("OreConfig"))
  -- If you moved PickaxeConfig into RojoShared, change to:
  -- local PickaxeConfig = require(ReplicatedStorage:WaitForChild("RojoShared"):WaitForChild("PickaxeConfig"))
  -- local OreConfig = require(ReplicatedStorage:WaitForChild("RojoShared"):WaitForChild("OreConfig"))

  local remotes = ReplicatedStorage:WaitForChild("Remotes")
  local mineRockEvent = remotes:WaitForChild("MineRock")

  local rockFolder = Workspace:WaitForChild("Rocks")

  -- >>> REPLACE with your real Hold-to-Mine gamepass ID <<<
  local HOLD_TO_MINE_PASS_ID = 0

  -- Match your server range (OreSystem HIT_RANGE = 15)
  local HIT_RANGE = 15
  local RAY_DISTANCE = 60
  local COOLDOWN_BUFFER = 0.06

  local nextSwingAt = 0
  local swingAnimation = tool:FindFirstChild("SwingAnimation")
  local swingTrack
  local swingSound = tool:FindFirstChild("SwingSound")

  local holding = false
  local ownsHold = false
  local cachedOwnsHold = nil
  local rarityColors = OreConfig.RarityColors or {}
  local highlightBox
  local highlightedRock
  local lastStreakToast = 0

  local connections = {}

  local function disconnectAll()
    for _, c in ipairs(connections) do
      if c and c.Connected then
        c:Disconnect()
      end
    end
    table.clear(connections)
  end

  local function getMouse()
    if not mouse then
      mouse = player:GetMouse()
    end
    return mouse
  end

  local function getHRP()
    if not character then
      return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
  end

  local function getCurrentCooldown()
    local tierValue = player:FindFirstChild("PickaxeTier")
    local tierIndex = 1
    if tierValue and typeof(tierValue.Value) == "number" then
      tierIndex = math.clamp(tierValue.Value, 1, PickaxeConfig.GetTierCount())
    end
    local cfg = PickaxeConfig.GetTier(tierIndex) or {}

    local baseCooldown = cfg.Cooldown or 0.5
    local momentum = player:GetAttribute("MiningMomentum") or 1

    return math.max(0.1, baseCooldown / momentum)
  end

  local function isRockInstance(inst)
    if not inst or not rockFolder then
      return false
    end
    return inst:IsDescendantOf(rockFolder)
  end

  local function getRockModelFromHit(inst)
    if not inst then
      return nil
    end

    local m = inst
    if inst:IsA("BasePart") then
      m = inst:FindFirstAncestorWhichIsA("Model") or inst.Parent
    end

    if m and m:IsA("Model") and m:IsDescendantOf(rockFolder) then
      return m
    end

    return nil
  end

  local function isWithinRange(rockModel, hitPart)
    local hrp = getHRP()
    if not hrp then
      return false
    end

    local pos = nil
    if rockModel and rockModel.PrimaryPart then
      pos = rockModel.PrimaryPart.Position
    elseif hitPart and hitPart:IsA("BasePart") then
      pos = hitPart.Position
    end
    if not pos then
      return false
    end

    return (hrp.Position - pos).Magnitude <= HIT_RANGE
  end

  local function computeOwnsHold()
    -- DEV override from your DevCommands: ForceHoldToMine attribute
    if player:GetAttribute("ForceHoldToMine") == true then
      return true
    end

    if cachedOwnsHold ~= nil then
      return cachedOwnsHold
    end

    if HOLD_TO_MINE_PASS_ID == 0 then
      cachedOwnsHold = false
      return false
    end

    local ok, result = pcall(function()
      return MarketplaceService:UserOwnsGamePassAsync(player.UserId, HOLD_TO_MINE_PASS_ID)
    end)

    cachedOwnsHold = (ok and result == true)
    return cachedOwnsHold
  end

  local function refreshHoldPass()
    ownsHold = computeOwnsHold()
  end

  local function getRockPartUnderCursor()
    local mouseObj = getMouse()
    if not mouseObj then
      return nil
    end

    -- Direct target
    local direct = mouseObj.Target
    if direct and isRockInstance(direct) then
      return direct
    end

    -- Raycast only against rocks
    local camera = Workspace.CurrentCamera
    if not camera then
      return nil
    end

    local origin = camera.CFrame.Position
    local dir = mouseObj.UnitRay.Direction * RAY_DISTANCE

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Include
    rayParams.FilterDescendantsInstances = { rockFolder }

    local result = Workspace:Raycast(origin, dir, rayParams)
    if result and result.Instance and isRockInstance(result.Instance) then
      return result.Instance
    end

    return nil
  end

  local function clearHighlight()
    highlightedRock = nil
    if highlightBox then
      highlightBox.Adornee = nil
      highlightBox.Visible = false
    end
  end

  local function updateHighlight()
    clearHighlight()
  end

  local function showStreakToast()
    lastStreakToast = os.clock()
  end

  local function playSwingAnim()
    if swingTrack then
      swingTrack:Play()
    end
  end

  local function trySwing()
    local now = os.clock()
    local cooldown = getCurrentCooldown()

    if now < nextSwingAt then
      return
    end

    nextSwingAt = now + cooldown + COOLDOWN_BUFFER

    local hitPart = getRockPartUnderCursor()
    local rock = getRockModelFromHit(hitPart)
    if not rock or not isWithinRange(rock, hitPart) then
      return
    end

    playSwingAnim()
    if swingSound then
      swingSound:Play()
    end

    mineRockEvent:FireServer(hitPart)
  end

  local function startHolding()
    if holding then
      return
    end
    holding = true

    -- No pass: one swing per click
    if not ownsHold then
      trySwing()
      holding = false
      return
    end

    task.spawn(function()
      while holding and tool.Parent == character do
        trySwing()
        local waitTime = math.max(0.01, nextSwingAt - os.clock())
        task.wait(waitTime)
      end
    end)
  end

  local function stopHolding()
    holding = false
  end

  -- Connections
  table.insert(connections, tool.Equipped:Connect(function()
    character = tool.Parent

    swingAnimation = tool:FindFirstChild("SwingAnimation")
    swingSound = tool:FindFirstChild("SwingSound")

    if swingAnimation and character then
      local humanoid = character:FindFirstChildOfClass("Humanoid")
      if humanoid then
        swingTrack = humanoid:LoadAnimation(swingAnimation)
      end
    end

    refreshHoldPass()
  end))

  table.insert(connections, tool.Unequipped:Connect(function()
    stopHolding()
    clearHighlight()
    character = nil

    if swingTrack then
      swingTrack:Stop()
      swingTrack = nil
    end
  end))

  table.insert(connections, tool.Activated:Connect(function()
    refreshHoldPass()
    startHolding()
  end))

  table.insert(connections, tool.Deactivated:Connect(function()
    stopHolding()
  end))

  table.insert(connections, player:GetAttributeChangedSignal("ForceHoldToMine"):Connect(function()
    cachedOwnsHold = nil
    refreshHoldPass()
  end))

  table.insert(connections, MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, passId, purchased)
    if plr == player and passId == HOLD_TO_MINE_PASS_ID and purchased then
      cachedOwnsHold = true
      refreshHoldPass()
    end
  end))

  table.insert(connections, player:GetAttributeChangedSignal("MiningStreak"):Connect(function()
    showStreakToast()
  end))

  -- Return a cleanup function in case you ever want it
  return function()
    stopHolding()
    clearHighlight()
    disconnectAll()
  end
end

return PickaxeClient
