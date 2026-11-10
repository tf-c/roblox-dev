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

	["a bundle id is a bundle look"] = function()
		Assert.eq(Outfit.source({ bundleId = 722 }), "bundle")
	end,

	["an outfit id is an outfit look"] = function()
		Assert.eq(Outfit.source({ outfitId = 5 }), "outfit")
	end,

	["a manual table is a manual look"] = function()
		Assert.eq(Outfit.source({ manual = {} }), "manual")
	end,

	["a look with no source is nil"] = function()
		Assert.eq(Outfit.source({}), nil)
	end,

	["a look with two sources is nil"] = function()
		Assert.eq(Outfit.source({ bundleId = 1, outfitId = 2 }), nil)
	end,

	["manual lists and ids map to description properties"] = function()
		local result = Outfit.manualProperties({ hats = { 1, 2 }, waist = { 9 }, shirt = 77 })
		Assert.eq(result.HatAccessory, "1,2")
		Assert.eq(result.WaistAccessory, "9")
		Assert.eq(result.Shirt, 77)
		local count = 0
		for _ in result do
			count += 1
		end
		Assert.eq(count, 3)
	end,

	["an empty manual look has no properties"] = function()
		Assert.eq(next(Outfit.manualProperties({})), nil)
	end,

	["catalog asset types map to accessory slots"] = function()
		Assert.eq(Outfit.accessorySlot(8), "Hat")
		Assert.eq(Outfit.accessorySlot(41), "Hair")
		Assert.eq(Outfit.accessorySlot(42), "Face")
		Assert.eq(Outfit.accessorySlot(44), "Shoulder")
		Assert.eq(Outfit.accessorySlot(47), "Waist")
		Assert.eq(Outfit.accessorySlot(11), nil) -- a shirt is not an accessory
	end,
}
