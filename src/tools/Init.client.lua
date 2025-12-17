-- ReplicatedStorage/Tools/Pickaxe/Init.client.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("RojoShared")
local tool = script.Parent

local ok, PV = pcall(function() return require(Shared:WaitForChild("PickaxeVisuals")) end)
if ok and PV and PV.init then
	PV.init(tool)
end

local ok2, Client = pcall(function() return require(Shared:WaitForChild("PickaxeClient")) end)
if ok2 and type(Client)=="table" and Client.init then
	Client.init(tool)
end
