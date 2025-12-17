-- ServerScriptService/EquipPickaxe.server.lua
local RS = game:GetService("ReplicatedStorage")

local function getTemplate()
	local tools = RS:FindFirstChild("Tools"); assert(tools, "ReplicatedStorage/Tools missing")
	local pickaxe = tools:FindFirstChild("Pickaxe"); assert(pickaxe and pickaxe:IsA("Tool"), "ReplicatedStorage/Tools/Pickaxe must be a Tool")
	return pickaxe
end

game.Players.PlayerAdded:Connect(function(p)
	-- Ensure PickaxeTier exists
	if not p:FindFirstChild("PickaxeTier") then
		local v = Instance.new("IntValue")
		v.Name = "PickaxeTier"
		v.Value = 1
		v.Parent = p
	end

	p.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid")
		local bp  = p:WaitForChild("Backpack")

		for _, t in ipairs(bp:GetChildren()) do
			if t:IsA("Tool") and t.Name:lower():find("pickaxe") then t:Destroy() end
		end

		local clone = getTemplate():Clone()
		clone:SetAttribute("IsPickaxe", true)
		clone.Parent = bp
		task.defer(function()
			if hum then hum:EquipTool(clone) end
		end)
		print(("✅ [EquipPickaxe] Equipped Pickaxe to %s parent: %s"):format(
			p.Name, clone.Parent and clone.Parent:GetFullName() or "nil"))
	end)
end)
