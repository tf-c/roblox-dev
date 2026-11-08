--!strict
local Assert = require("./assert")
local Outfit = require("../src/shared/Outfit")

return {
	["picks the only UserOutfit"] = function()
		local items = {
			{ Id = 1, Name = "Cat Boy", Type = "Asset" },
			{ Id = 2, Name = "Cat Boy", Type = "UserOutfit" },
		}
		Assert.eq(Outfit.pickOutfitId(items), 2)
	end,

	["skips a head-only outfit"] = function()
		local items = {
			{ Id = 3, Name = "Cat Head", Type = "UserOutfit" },
			{ Id = 4, Name = "Cat Boy", Type = "UserOutfit" },
		}
		Assert.eq(Outfit.pickOutfitId(items), 4)
	end,

	["returns nil when only a head outfit exists"] = function()
		Assert.eq(Outfit.pickOutfitId({ { Id = 5, Name = "Cat Head", Type = "UserOutfit" } }), nil)
	end,

	["returns nil for an empty list"] = function()
		Assert.eq(Outfit.pickOutfitId({}), nil)
	end,

	["returns the first of two usable outfits"] = function()
		local items = {
			{ Id = 6, Name = "A", Type = "UserOutfit" },
			{ Id = 7, Name = "B", Type = "UserOutfit" },
		}
		Assert.eq(Outfit.pickOutfitId(items), 6)
	end,

	["accessories join an empty string"] = function()
		Assert.eq(Outfit.withAccessories("", { 101, 102 }), "101,102")
	end,

	["accessories append to existing ones"] = function()
		Assert.eq(Outfit.withAccessories("55", { 101 }), "55,101")
	end,

	["no extras keeps the existing string"] = function()
		Assert.eq(Outfit.withAccessories("55", {}), "55")
	end,

	["nothing plus nothing is empty"] = function()
		Assert.eq(Outfit.withAccessories("", {}), "")
	end,
}
