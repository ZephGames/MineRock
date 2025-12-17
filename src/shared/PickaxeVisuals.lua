-- ReplicatedStorage/RojoShared/PickaxeVisuals.lua
-- Production: no console spam. No-flicker mount + alignment (Grip -> Config -> Defaults -> Heuristic).

local Players        = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")

local PickaxeVisuals = {}
PickaxeVisuals.DEBUG = false -- keep for emergency; otherwise silent

-- Optional built-in defaults for assets with odd pivots (only used if no Grip & no Config)
local DEFAULT_OFFSETS = {
	ForemanSteel = { offset = Vector3.new(0, -1.35, -0.55), angles = Vector3.new(-10, -90, 10) },
}

local function gatherParts(root)
	local t = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then t[#t+1] = d end
	end
	return t
end

local function getTierIndex(player)
	local iv = player and player:FindFirstChild("PickaxeTier")
	if iv and typeof(iv.Value) == "number" then return iv.Value end
	local a = player and player:GetAttribute("PickaxeTier")
	if typeof(a) == "number" then return a end
	return 1
end

local function findTemplate(modelsFolder, cfg, idx)
	if not modelsFolder then return nil end
	if cfg.ModelName and modelsFolder:FindChild(cfg.ModelName) then return modelsFolder[cfg.ModelName] end
	if cfg.Id and modelsFolder:FindChild(cfg.Id) then return modelsFolder[cfg.Id] end
	local guess = "Pickaxe"..idx
	return modelsFolder:FindChild(guess)
end

local function cloneAsModel(template)
	local inst = template:Clone()
	if inst:IsA("Model") then
		if not inst.PrimaryPart then
			for _, d in ipairs(inst:GetDescendants()) do
				if d:IsA("BasePart") then inst.PrimaryPart = d break end
			end
		end
		return inst
	end
	local model = Instance.new("Model")
	model.Name = template.Name
	inst.Parent = model
	local primary = inst:IsA("BasePart") and inst or nil
	if not primary then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then primary = d break end
		end
	end
	if primary then model.PrimaryPart = primary end
	return model
end

-- alignment strategies
local function alignUsingGripAttachment(model, handle)
	local grip = model:FindFirstChild("Grip", true)
	if grip and grip:IsA("Attachment") then
		local mcf = model:GetPivot()
		local localGrip = mcf:ToObjectSpace(grip.WorldCFrame)
		return handle.CFrame * localGrip:Inverse()
	end
	return nil
end

local function alignUsingConfig(handle, cfg)
	local off, ang = cfg.MountOffset, cfg.MountAngles
	if typeof(off) == "Vector3" or typeof(ang) == "Vector3" then
		local cf = handle.CFrame
		if typeof(off) == "Vector3" then cf = cf * CFrame.new(off) end
		if typeof(ang) == "Vector3" then cf = cf * CFrame.Angles(math.rad(ang.X), math.rad(ang.Y), math.rad(ang.Z)) end
		return cf
	end
	return nil
end

local function alignUsingDefaults(handle, cfg)
	local def = DEFAULT_OFFSETS[cfg.Id]
	if def then
		local cf = handle.CFrame
		if def.offset then cf = cf * CFrame.new(def.offset) end
		if def.angles then cf = cf * CFrame.Angles(math.rad(def.angles.X), math.rad(def.angles.Y), math.rad(def.angles.Z)) end
		return cf
	end
	return nil
end

local function alignUsingHeuristic(model, handle)
	local _, size = model:GetBoundingBox()
	local down = -math.clamp(size.Y * 0.35, 0.2, 1.2)
	local fwd  = -math.clamp(size.Z * 0.20, 0.15, 0.9)
	return handle.CFrame * CFrame.new(0, down, fwd)
end

local function chooseAlignment(model, handle, cfg)
	return alignUsingGripAttachment(model, handle)
		or alignUsingConfig(handle, cfg)
		or alignUsingDefaults(handle, cfg)
		or alignUsingHeuristic(model, handle)
end

-- no-flicker mount
local function mountModelToHandle(model, handle, cfg)
	local parts = gatherParts(model)
	local savedTransparency = table.create(#parts)
	for i, p in ipairs(parts) do
		savedTransparency[i] = p.Transparency
		p.Anchored   = true
		p.CanCollide = false
		p.CanTouch   = false
		p.CanQuery   = false
		p.Massless   = true
		p.Transparency = 1
	end

	local cf = chooseAlignment(model, handle, cfg)
	model:PivotTo(cf)

	for _, p in ipairs(parts) do
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = p, handle
		w.Parent = p
	end

	for i, p in ipairs(parts) do
		p.Anchored = false
		p.Transparency = savedTransparency[i] or 0
	end

	handle.Anchored   = false
	handle.CanCollide = false
	handle.CanTouch   = false
	handle.CanQuery   = false
	handle.Massless   = true
end

function PickaxeVisuals.init(tool)
	if not (tool and tool:IsA("Tool")) then return end

	local player = Players.LocalPlayer
	local Shared = ReplicatedStorage:WaitForChild("RojoShared")
	local PickaxeConfig = require(Shared:WaitForChild("PickaxeConfig"))
	local ModelsFolder  = ReplicatedStorage:FindFirstChild("PickaxeModels")
	if not ModelsFolder then return end

	tool.CanBeDropped = false
	tool.RequiresHandle = true

	local handle = tool:FindFirstChild("Handle")
	if not (handle and handle:IsA("BasePart")) then
		handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.2,0.2,0.2)
		handle.Transparency = 1
		handle.CanCollide = false
		handle.Massless = true
		handle.Anchored = false
		handle.Parent = tool
	end
	handle.Transparency = 1
	handle.CanCollide   = false
	handle.CanTouch     = false
	handle.CanQuery     = false
	handle.Massless     = true
	handle.Anchored     = false

	local glow, activeModel, visualParts = nil, nil, {}
	local rainbow, hue = false, 0
	local function ensureGlow()
		if glow then return glow end
		local L = Instance.new("PointLight")
		L.Name = "PickaxeGlow"
		L.Range = 12
		L.Brightness = 0
		L.Enabled = false
		L.Parent = handle
		glow = L
		return L
	end

	local applying = false
	local function clearModel()
		if activeModel then activeModel:Destroy() activeModel = nil end
		for _, ch in ipairs(tool:GetChildren()) do
			if ch.Name == "_ActiveModel" and ch:IsA("Model") then ch:Destroy() end
		end
		visualParts, rainbow, hue = {}, false, 0
	end

	local function applyTier()
		if applying then return end
		applying = true

		local idx = math.clamp(getTierIndex(player), 1, PickaxeConfig.GetTierCount())
		local cfg = PickaxeConfig.GetTier(idx) or {}
		local disp = cfg.DisplayName or cfg.Id or ("Pickaxe "..idx)
		tool.Name, tool.ToolTip = disp, disp

		local template = findTemplate(ModelsFolder, cfg, idx)
		if not template then applying = false return end

		clearModel()
		activeModel = cloneAsModel(template)
		activeModel.Name = "_ActiveModel"
		activeModel.Parent = tool

		if (cfg.SizeScale and type(cfg.SizeScale)=="number") then
			activeModel:ScaleTo(cfg.SizeScale)
		end

		mountModelToHandle(activeModel, handle, cfg)
		visualParts = gatherParts(activeModel)

		local color = cfg.Color or Color3.new(1,1,1)
		local L = ensureGlow()
		L.Brightness = cfg.GlowBrightness or 0
		L.Enabled = L.Brightness > 0
		rainbow = cfg.RainbowGlow or false
		if not rainbow then L.Color = color end
		for _, p in ipairs(visualParts) do
			p.Material = (L.Brightness > 0) and Enum.Material.Neon or Enum.Material.Metal
			p.Color = color
		end

		applying = false
	end

	RunService.Heartbeat:Connect(function(dt)
		if rainbow and glow and #visualParts > 0 then
			hue = (hue + dt * 0.20) % 1
			local c = Color3.fromHSV(hue, 1, 1)
			glow.Color = c
			for _, p in ipairs(visualParts) do
				p.Material = Enum.Material.Neon
				p.Color = c
			end
		end
	end)

	tool.Equipped:Connect(applyTier)
	tool.AncestryChanged:Connect(applyTier)
	local iv = player and player:FindFirstChild("PickaxeTier")
	if iv then iv.Changed:Connect(applyTier) end
	if player then player:GetAttributeChangedSignal("PickaxeTier"):Connect(applyTier) end
	task.defer(applyTier)
end

return PickaxeVisuals
