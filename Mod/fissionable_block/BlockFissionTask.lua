--[[
Title: Split a Block task
Author(s): phf
Date: 2017/05/18
Desc: split fissionable block at the given position.
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/fissionable_block/BlockFissionTask.lua");
local BlockFissionTask = commonlib.gettable("MyCompany.Aries.Game.Tasks.BlockFissionTask");
local task = BlockFissionTask:new({blockX = result.blockX,blockY = result.blockY, blockZ = result.blockZ, data=nil, side = nil, side_region=[nil, "upper", "lower"], block_id = 1, entityPlayer, itemStack})
task:Run();
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/Tasks/UndoManager.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Items/ItemClient.lua");

local ItemClient = commonlib.gettable("MyCompany.Aries.Game.Items.ItemClient");
local UndoManager = commonlib.gettable("MyCompany.Aries.Game.UndoManager");
local BlockEngine = commonlib.gettable("MyCompany.Aries.Game.BlockEngine")
local TaskManager = commonlib.gettable("MyCompany.Aries.Game.TaskManager")
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic")

local BlockFissionTask = commonlib.inherit(commonlib.gettable("MyCompany.Aries.Game.Task"), commonlib.gettable("MyCompany.Aries.Game.Tasks.BlockFissionTask"));

function BlockFissionTask:ctor()
end

function BlockFissionTask:Run()
	self.finished = true;
	self.history = {};

	local worldName = ParaWorld.GetWorldName()
	local curWorld = ParaBlockWorld.GetWorld(worldName)

	if(not self.level) then
		self.level = "";
	end
	if(not self.color) then
		self.color = 0;
	end
	--print(string.format("x=%d,y=%d,z=%d",self.blockX,self.blockY,self.blockZ));
	self.last_template_id = ParaBlockWorld.GetBlockTexture(curWorld,self.blockX,self.blockY,self.blockZ,self.level);
	self.last_color = ParaBlockWorld.GetBlockColor(curWorld,self.blockX,self.blockY,self.blockZ,self.level);

	if(self.action == "destory") then
		ParaBlockWorld.DestroyBlock(curWorld, self.blockX,self.blockY,self.blockZ, self.level);
		print(string.format("destory block : x=%d,y=%d,z=%d,level=%s",self.blockX,self.blockY,self.blockZ,  self.level));
	elseif(self.action == "split") then
		ParaBlockWorld.SplitBlock(curWorld, self.blockX,self.blockY,self.blockZ, self.level);
	elseif(self.action == "set_property") then
		local tid = self.template_id or -1;
		ParaBlockWorld.SetBlockTexture(curWorld, self.blockX,self.blockY,self.blockZ, self.level,tid);
		ParaBlockWorld.SetBlockColor(curWorld, self.blockX,self.blockY,self.blockZ, self.level, self.color);
		print(string.format("set_property: x=%d,y=%d,z=%d,level=%s,template_id=%d,color=%d",
		self.blockX,self.blockY,self.blockZ,  self.level,tid,self.color));
	end
	local add_to_history;

	if(GameLogic.GameMode:CanAddToHistory()) then
		add_to_history = true;
		self.add_to_history = true;
	end
	
	if(add_to_history) then
		UndoManager.PushCommand(self);
		--echo(self)
	end

	if(self.blockX) then
		local tx, ty, tz = BlockEngine:real(self.blockX,self.blockY,self.blockZ);
		GameLogic.PlayAnimation({animationName = "Create",facingTarget = {x=tx, y=ty, z=tz},});
	end
end

function BlockFissionTask:Redo()
	--print(string.format("redo"));
	if(self.blockX) then
		--echo("phf  i am redoing");
		--BlockEngine:SetBlock(self.blockX,self.blockY,self.blockZ, self.block_id, self.data, 3, self.entity_data);
		local worldName = ParaWorld.GetWorldName()
		local curWorld = ParaBlockWorld.GetWorld(worldName)
		if(self.action == "destory") then
			ParaBlockWorld.DestroyBlock(curWorld, self.blockX,self.blockY,self.blockZ, self.level);
		elseif(self.action == "split") then
			local ret = ParaBlockWorld.SplitBlock(curWorld, self.blockX,self.blockY,self.blockZ, self.level);
			--print("phf said that redo SplitBlock result is:");
			--print(ret);
		elseif(self.action == "set_property") then
			local tid = self.template_id or -1;
			ParaBlockWorld.SetBlockTexture(curWorld, self.blockX,self.blockY,self.blockZ,  self.level, tid);
			ParaBlockWorld.SetBlockColor(curWorld, self.blockX,self.blockY,self.blockZ, self.level, self.color);
			print(string.format("redo SetBlockTexture and color: x=%d,y=%d,z=%d,level=%s,template_id=%d,color=%d",
		self.blockX,self.blockY,self.blockZ,  self.level,tid,self.color));
		end
	end
end

function BlockFissionTask:Undo()
	--print(string.format("undo"));
	if(self.blockX) then
		local worldName = ParaWorld.GetWorldName();
		local curWorld = ParaBlockWorld.GetWorld(worldName);
		local tid = self.template_id or -1;
		if(self.action == "destory") then
			ParaBlockWorld.RestoreBlock(curWorld, self.blockX,self.blockY,self.blockZ, self.level);
			ParaBlockWorld.SetBlockTexture(curWorld,self.blockX,self.blockY,self.blockZ, self.level,tid);
			ParaBlockWorld.SetBlockColor(curWorld,self.blockX,self.blockY,self.blockZ, self.level,self.color);
			print(string.format("undo destory block : x=%d,y=%d,z=%d,level=%s,template_id=%d,color=%d",
				self.blockX,self.blockY,self.blockZ,  self.level,tid,self.color));
		elseif(self.action == "split") then
			ParaBlockWorld.MergeBlock(curWorld, self.blockX,self.blockY,self.blockZ, self.level);
		elseif(self.action == "set_property") then
			tid = self.last_template_id or -1;
			ParaBlockWorld.SetBlockTexture(curWorld, self.blockX,self.blockY,self.blockZ, self.level, tid);
			ParaBlockWorld.SetBlockColor(curWorld, self.blockX,self.blockY,self.blockZ, self.level, self.last_color);
			print(string.format("undo set_property x=%d,y=%d,z=%d,color=%d,last_color=%d,last_template_id=%d,level=%s",
				self.blockX,self.blockY,self.blockZ,self.color,self.last_color,tid,self.level));
		end
	end
end

function BlockFissionTask:SetItemStack(itemStack)
	self.itemStack = itemStack;
end

function BlockFissionTask:GetItemStack()
	return self.itemStack;
end
