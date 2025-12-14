-- ServerScriptService/GamepassCache

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- PUT YOUR IDS HERE
local HOLD_TO_MINE_PASS_ID = 1631480540 -- <<<< change
local SELL_ANYWHERE_PASS_ID = 1631522468 -- <<<< change

local cache = {} -- cache[player] = { hold=true/false, sell=true/false }

local function ownsPass(userId, passId)
	local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, userId, passId)
	if not ok then
		return false
	end
	return result == true
end

local function refreshPlayer(plr)
	cache[plr] = cache[plr] or {}

	-- OPTIONAL: studio testing for only YOU
	-- If you don't want this, delete this if block
	if RunService:IsStudio() and plr.UserId == 2527826821 then
		cache[plr].hold = true
		cache[plr].sell = true
		return
	end

	cache[plr].hold = ownsPass(plr.UserId, HOLD_TO_MINE_PASS_ID)
	cache[plr].sell = ownsPass(plr.UserId, SELL_ANYWHERE_PASS_ID)
end

Players.PlayerAdded:Connect(refreshPlayer)

Players.PlayerRemoving:Connect(function(plr)
	cache[plr] = nil
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, passId, purchased)
	if not purchased then return end
	if not cache[plr] then cache[plr] = {} end

	if passId == HOLD_TO_MINE_PASS_ID then
		cache[plr].hold = true
	elseif passId == SELL_ANYWHERE_PASS_ID then
		cache[plr].sell = true
	end
end)

-- Expose functions to other server scripts through _G (simple + reliable)
_G.HasHoldToMine = function(plr)
	return cache[plr] and cache[plr].hold == true
end

_G.HasSellAnywhere = function(plr)
	return cache[plr] and cache[plr].sell == true
end
