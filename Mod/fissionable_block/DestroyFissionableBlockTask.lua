--[[
Title: Destroy Fissionable Block task
Author(s): phf
Date: 2017/05/18
Desc: Destroy a single fissionable block at the given position.
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/fissionable_block/DestroyFissionableBlockTask.lua");
local DestroyFissionableBlockTask = commonlib.gettable("MyCompany.Aries.Game.Tasks.DestroyFissionableBlock");
local task = DestroyFissionableBlockTask:new({blockX = result.blockX,blockY = result.blockY, blockZ = result.blockZ})
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

local DestroyFissionableBlock = commonlib.inherit(commonlib.gettable("MyCompany.Aries.Game.Task"), commonlib.gettable("MyCompany.Aries.Game.Tasks.DestroyFissionableBlockTask"));

function DestroyFissionableBlock:ctor()
end

function DestroyFissionableBlock:Run()
	self.finished = true;
	if(not self.blockX) then
		return;
	end
	local add_to_history;
	
	local block_id = BlockEngine:GetBlockId(self.blockX,self.blockY,self.blockZ);
	if(block_id > 0) then
		local block_template = block_types.get(block_id);
		if(block_template) then
			self.last_block_id = block_id;
			local worldName = ParaWorld.GetWorldName();
			local curWorld = ParaBlockWorld.GetWorld(worldName);
			self.last_template_id = ParaBlockWorld.GetBlockTexture(curWorld,self.blockX,self.blockY,self.blockZ,"");
			self.last_color = ParaBlockWorld.GetBlockColor(curWorld,self.blockX,self.blockY,self.blockZ,"");
			print(string.format("DestroyFissionableBlock Run:last_template_id=%d,last_color=%d",self.last_template_id,self.last_color))
			-- needs to be called before Remove() so that we can get entity data
			local dropped_itemStack = block_template:GetDroppedItemStack(self.blockX,self.blockY,self.blockZ);

			local blocks_modified = block_template:Remove(self.blockX,self.blockY,self.blockZ);
			if(blocks_modified) then
				-- invoke callback. 
				local entityPlayer = EntityManager.GetPlayer();
				block_template:OnUserBreakItem(self.blockX,self.blockY,self.blockZ, entityPlayer);

				if(dropped_itemStack) then
					-- automatically pick the block when deleted. 
					if(entityPlayer) then
						entityPlayer:PickItem(dropped_itemStack, self.blockX,self.blockY,self.blockZ);
					end
				end

				-- only allow history operation if no auto generated blocks are created when the block is destroyed. 
				if(GameLogic.GameMode:CanAddToHistory()) then
					add_to_history = true;
				end
			end
		end
	else
		-- if there is no block, we may have hit the terrain. 
		-- TODO: block.RemoveTerrainBlock(self.blockX,self.blockY,self.blockZ); ?
	end
	
	if(add_to_history) then
		UndoManager.PushCommand(self);
	end
end

function DestroyFissionableBlock:Redo()
	if(self.blockX and self.block_id) then
		echo("DestroyFissionableBlock phf  i am redoing");
		BlockEngine:SetBlockToAir(self.blockX,self.blockY,self.blockZ, 0);
	end
end

function DestroyFissionableBlock:Undo()
	if(self.blockX and self.block_id) then
		echo("DestroyFissionableBlock phf  i am undoing");
		local worldName = ParaWorld.GetWorldName();
		local curWorld = ParaBlockWorld.GetWorld(worldName);
		ParaTerrain.SetBlockTemplateByIdx(self.blockX,self.blockY,self.blockZ,self.last_block_id);
		ParaBlockWorld.SetBlockTexture(curWorld, self.blockX,self.blockY,self.blockZ, "",self.last_template_id);
		ParaBlockWorld.SetBlockColor(curWorld, self.blockX,self.blockY,self.blockZ, "", self.last_color);
		--BlockEngine:SetBlock(self.blockX,self.blockY,self.blockZ, self.last_block_id, self.last_block_data, nil, self.last_entity_data);
	end
end
