-- ReplicatedStorage/Tools/Pickaxe/Init.client.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("RojoShared")
local tool = script.Parent

warn("[INIT] starting; tool =", tool:GetFullName())

local ok, PV = pcall(function() return require(Shared:WaitForChild("PickaxeVisuals")) end)
if not ok then
	warn("[INIT] FAILED to require PickaxeVisuals:", PV)
else
	warn("[INIT] PickaxeVisuals acquired; calling init()")
	PV.DEBUG = true
	PV.init(tool)
end

-- optional gameplay module if you have it:
local ok2, Client = pcall(function() return require(Shared:WaitForChild("PickaxeClient")) end)
if ok2 and type(Client)=="table" and Client.init then
	warn("[INIT] PickaxeClient acquired; calling init()")
	Client.init(tool)
end
