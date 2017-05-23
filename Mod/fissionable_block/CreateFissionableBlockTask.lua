--[[
Title: Create Fissionable Block task
Author(s): phf
Date: 2017/05/18
Desc: Create a single fissionable block at the given position.
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/fissionable_block/CreateFissionableBlockTask.lua");
-- @param side: this is OPPOSITE of the touching side
local task = MyCompany.Aries.Game.Tasks.CreateFissionableBlock:new({blockX = result.blockX,blockY = result.blockY, blockZ = result.blockZ, data=nil, side = nil, side_region=[nil, "upper", "lower"], block_id = 1, entityPlayer, itemStack})
task:Run();
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/Tasks/UndoManager.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Items/ItemClient.lua");

local FissionContext = commonlib.gettable("Mod.FissionableBlock.FissionContext");
local ItemClient = commonlib.gettable("MyCompany.Aries.Game.Items.ItemClient");
local UndoManager = commonlib.gettable("MyCompany.Aries.Game.UndoManager");
local BlockEngine = commonlib.gettable("MyCompany.Aries.Game.BlockEngine")
local TaskManager = commonlib.gettable("MyCompany.Aries.Game.TaskManager")
local block_types = commonlib.gettable("MyCompany.Aries.Game.block_types")
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic")
local EntityManager = commonlib.gettable("MyCompany.Aries.Game.EntityManager");

local CreateFissionableBlock = commonlib.inherit(commonlib.gettable("MyCompany.Aries.Game.Task"), commonlib.gettable("MyCompany.Aries.Game.Tasks.CreateFissionableBlock"));

function CreateFissionableBlock:ctor()
end

-- @return bCreated
function CreateFissionableBlock:TryCreateSingleBlock()
	local item = ItemClient.GetItem(self.block_id);
	if(item) then
		item.current_block_status = self.current_block_status;
		local entityPlayer = self.entityPlayer;
		local itemStack;
		local isUsed;
		if(entityPlayer) then
			itemStack = self.itemStack or entityPlayer.inventory:GetItemInRightHand();
			if(itemStack) then
				if(GameLogic.GameMode:IsEditor()) then
					EntityManager.GetPlayer().inventory:PickBlock(block_id);
					-- does not decrease count in creative mode. 
					local oldCount = itemStack.count;
					--echo("phf itemstack")
					--echo(itemStack)
					isUsed = itemStack:TryCreate(entityPlayer, self.blockX,self.blockY,self.blockZ, self.side, self.data, self.side_region);
					itemStack.count = oldCount;
				else
					isUsed = itemStack:TryCreate(entityPlayer, self.blockX,self.blockY,self.blockZ, self.side, self.data, self.side_region);	
					if(isUsed) then
						entityPlayer.inventory:OnInventoryChanged(entityPlayer.inventory:GetHandToolIndex());
					end
				end
			end
		else
			isUsed = item:TryCreate(nil, EntityManager.GetPlayer(), self.blockX,self.blockY,self.blockZ, self.side, self.data, self.side_region);
		end
			
		return isUsed;
	end
end

function CreateFissionableBlock:Run()
	self.finished = true;
	self.history = {};

	local add_to_history;

	local blocks;
	--_guihelper.MessageBox("step1");
	if(self.block_id) then
		if(not self.blockX) then
			local player = self.entityPlayer or EntityManager.GetPlayer();
			if(player) then
				self.blockX, self.blockY, self.blockZ = player:GetBlockPos();
			end
			if(not self.blockX) then
				return;
			end
		end
		
		self.last_block_id = BlockEngine:GetBlockId(self.blockX,self.blockY,self.blockZ);
		self.last_block_data = BlockEngine:GetBlockData(self.blockX,self.blockY,self.blockZ);
		self.last_entity_data = BlockEngine:GetBlockEntityData(self.blockX,self.blockY,self.blockZ);

		if(self:TryCreateSingleBlock()) then

			local block_id, block_data, entity_data = BlockEngine:GetBlockFull(self.blockX, self.blockY, self.blockZ);
			if(block_id == self.block_id) then
				self.data = block_data;
				self.entity_data = entity_data;

				local tx, ty, tz = BlockEngine:real(self.blockX,self.blockY,self.blockZ);
				GameLogic.PlayAnimation({facingTarget = {x=tx, y=ty, z=tz},});
				GameLogic.events:DispatchEvent({type = "CreateFissionableBlockTask" , block_id = self.block_id, block_data = block_data, x = self.blockX, y = self.blockY, z = self.blockZ,
					last_block_id = self.last_block_id, last_block_data = self.last_block_data});
			end

			if(GameLogic.GameMode:CanAddToHistory()) then
				add_to_history = true;
				self.add_to_history = true;
			end
		else
			return
		end
	end
	
	if(add_to_history) then
		UndoManager.PushCommand(self);
	end

	if(self.blockX) then
		local tx, ty, tz = BlockEngine:real(self.blockX,self.blockY,self.blockZ);
		GameLogic.PlayAnimation({animationName = "Create",facingTarget = {x=tx, y=ty, z=tz},});
	end
end

function CreateFissionableBlock:Redo()
	if(self.blockX and self.block_id) then
		echo("CreateFissionableBlock phf  i am redoing");
		self:TryCreateSingleBlock();
	end
end

function CreateFissionableBlock:Undo()
	echo("CreateFissionableBlock phf  i am undoing");
	if(self.blockX and self.block_id) then
		BlockEngine:SetBlock(self.blockX,self.blockY,self.blockZ, self.last_block_id or 0, self.last_block_data,3, self.last_entity_data);
	end
end

function CreateFissionableBlock:SetItemStack(itemStack)
	self.itemStack = itemStack;
end

function CreateFissionableBlock:GetItemStack()
	return self.itemStack;
end
