-- ReplicatedStorage/RojoShared/PickaxeVisuals.lua
-- Mounts the correct tier model onto a permanent Tool.Handle
-- Works with Model or MeshPart templates. Supports Grip attachment or per-tier offsets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PickaxeVisuals = {}
PickaxeVisuals.DEBUG = true
local function d(...) if PickaxeVisuals.DEBUG then print("[PickaxeVisuals]", ...) end end

local function gatherParts(root)
	local t = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(t, d) end
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

local function findTemplate(ModelsFolder, cfg, idx)
	if not ModelsFolder then return nil end
	if cfg.ModelName and ModelsFolder:FindFirstChild(cfg.ModelName) then return ModelsFolder[cfg.ModelName] end
	if cfg.Id and ModelsFolder:FindFirstChild(cfg.Id) then return ModelsFolder[cfg.Id] end
	local guess = "Pickaxe"..idx
	return ModelsFolder:FindFirstChild(guess)
end

-- Clone and ensure we return a Model with a PrimaryPart
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
	local primary = nil
	if inst:IsA("BasePart") then
		primary = inst
	else
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then primary = d break end
		end
	end
	if primary then model.PrimaryPart = primary end
	return model
end

-- Alignment strategies
local function alignUsingGripAttachment(model, handle)
	local grip = model:FindFirstChild("Grip", true) -- Attachment anywhere inside
	if grip and grip:IsA("Attachment") then
		local mcf = model:GetPivot()
		local localGrip = mcf:ToObjectSpace(grip.WorldCFrame)
		return handle.CFrame * localGrip:Inverse()
	end
	return nil
end

local function alignUsingConfig(model, handle, cfg)
	local off = cfg.MountOffset
	local ang = cfg.MountAngles
	if typeof(off) == "Vector3" or typeof(ang) == "Vector3" then
		local cf = handle.CFrame
		if typeof(off) == "Vector3" then
			cf = cf * CFrame.new(off)
		end
		if typeof(ang) == "Vector3" then
			cf = cf * CFrame.Angles(math.rad(ang.X), math.rad(ang.Y), math.rad(ang.Z))
		end
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

local function mountModelToHandle(model, handle, cfg)
	local targetCF = alignUsingGripAttachment(model, handle)
		or alignUsingConfig(model, handle, cfg)
		or alignUsingHeuristic(model, handle)

	model:PivotTo(targetCF)

	for _, p in ipairs(gatherParts(model)) do
		p.Anchored  = false
		p.CanCollide= false
		p.CanTouch  = false
		p.CanQuery  = false
		p.Massless  = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = p
		w.Part1 = handle
		w.Parent = p
	end

	handle.Anchored = false
	handle.CanCollide = false
	handle.CanTouch  = false
	handle.CanQuery  = false
	handle.Massless  = true
end

function PickaxeVisuals.init(tool)
	assert(tool and tool:IsA("Tool"), "PickaxeVisuals.init expected a Tool")

	local player = Players.LocalPlayer
	local Shared = ReplicatedStorage:WaitForChild("RojoShared")
	local PickaxeConfig = require(Shared:WaitForChild("PickaxeConfig"))
	local ModelsFolder  = ReplicatedStorage:FindFirstChild("PickaxeModels")
	assert(ModelsFolder, "ReplicatedStorage/PickaxeModels missing")

	tool.CanBeDropped = false
	tool.RequiresHandle = true

	-- Ensure permanent tiny handle for Roblox grip
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

	-- Light for glow
	local glow = nil
	local function ensureGlow()
		if not glow then
			glow = Instance.new("PointLight")
			glow.Name = "PickaxeGlow"
			glow.Range = 12
			glow.Brightness = 0
			glow.Enabled = false
			glow.Parent = handle
		end
		return glow
	end

	local activeModel = nil
	local visualParts = {}
	local rainbow, hue = false, 0

	local function clearModel()
		if activeModel then activeModel:Destroy() activeModel = nil end
		for _, ch in ipairs(tool:GetChildren()) do
			if ch.Name == "_ActiveModel" and ch:IsA("Model") then ch:Destroy() end
		end
		visualParts = {}
		rainbow, hue = false, 0
	end

	local applying = false
	local function applyTier()
		if applying then return end
		applying = true

		local idx = math.clamp(getTierIndex(player), 1, PickaxeConfig.GetTierCount())
		local cfg = PickaxeConfig.GetTier(idx) or {}
		local disp = cfg.DisplayName or cfg.Id or ("Pickaxe "..idx)
		tool.Name = disp
		tool.ToolTip = disp

		local template = findTemplate(ModelsFolder, cfg, idx)
		if not template then d("No model for tier", idx, cfg.Id or "?") applying = false return end

		clearModel()
		activeModel = cloneAsModel(template)
		activeModel.Name = "_ActiveModel"
		activeModel.Parent = tool

		-- scale before alignment so offsets use final size
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

		d(("Applied tier %d (%s), parts=%d"):format(idx, tostring(cfg.Id), #visualParts))
		applying = false
	end

	RunService.Heartbeat:Connect(function(dt)
		if rainbow and glow and #visualParts > 0 then
			hue = (hue + dt * 0.20) % 1
			local c = Color3.fromHSV(hue,1,1)
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
