-- ReplicatedStorage/Tools/Pickaxe/Init.client.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("RojoShared")

local tool = script.Parent
if not tool:IsA("Tool") then
	-- Try to recover if the script was parented under a Folder/LocalScript
	tool = script:FindFirstAncestorWhichIsA("Tool")
		or (tool:IsA("Folder") and tool:FindFirstChildWhichIsA("Tool"))
		or tool
end

if not tool or not tool:IsA("Tool") then
	warn("[Pickaxe Init] Expected to run inside a Tool, got", tool and tool.ClassName or "nil")
	return
end

local ok, PV = pcall(function() return require(Shared:WaitForChild("PickaxeVisuals")) end)
if ok and PV and PV.init then
	PV.init(tool)
end

local ok2, Client = pcall(function() return require(Shared:WaitForChild("PickaxeClient")) end)
if ok2 and type(Client)=="table" and Client.init then
	Client.init(tool)
end
