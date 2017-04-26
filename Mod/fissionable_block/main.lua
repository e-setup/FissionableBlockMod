--[[
Title: 
Author(s):  
Date: 
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/fissionable_block/main.lua");
local fissionable_block = commonlib.gettable("Mod.fissionable_block");
------------------------------------------------------------
]]
NPL.load("(gl)Mod/fissionable_block/ItemFissionable.lua");

local FissionableItem = commonlib.gettable("Mod.Fissionable.ItemFissionable");
local fissionable_block = commonlib.inherit(commonlib.gettable("Mod.ModBase"),commonlib.gettable("Mod.fissionable_block"));

function fissionable_block:ctor()
end

-- virtual function get mod name

function fissionable_block:GetName()
	return "fissionable_block"
end

-- virtual function get mod description 

function fissionable_block:GetDesc()
	return "fissionable_block is a plugin in paracraft"
end

function fissionable_block:init()
	LOG.std(nil, "info", "fissionable_block", "plugin initialized");
	FissionableItem:init();
end

function fissionable_block:OnLogin()
end
-- called when a new world is loaded. 

function fissionable_block:OnWorldLoad()
end
-- called when a world is unloaded. 

function fissionable_block:OnLeaveWorld()
end

function fissionable_block:OnDestroy()
end
