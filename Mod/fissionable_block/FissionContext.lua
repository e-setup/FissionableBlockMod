
--[[
Title: FissionContext
Author(s): PHF
Date: 2017.4
Desc: Example of demo scene context
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/fissionable_block/FissionContext.lua");
local FissionContext = commonlib.gettable("Mod.FissionableBlock.FissionContext");
FissionContext:ApplyToDefaultContext();
------------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/SceneContext/BaseContext.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Tasks/UndoManager.lua");
local UndoManager = commonlib.gettable("MyCompany.Aries.Game.UndoManager");
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic")
local GameMode = commonlib.gettable("MyCompany.Aries.Game.GameLogic.GameMode");
local EntityManager = commonlib.gettable("MyCompany.Aries.Game.EntityManager");
local block_types = commonlib.gettable("MyCompany.Aries.Game.block_types")
local BlockEngine = commonlib.gettable("MyCompany.Aries.Game.BlockEngine")
local FissionContext = commonlib.inherit(commonlib.gettable("MyCompany.Aries.Game.SceneContext.BaseContext"), commonlib.gettable("Mod.FissionableBlock.FissionContext"));

FissionContext:Property("Name", "FissionContext");

function FissionContext:ctor()
	self:EnableAutoCamera(true);	
end

-- static method: use this demo scene context as default context
function FissionContext:ApplyToDefaultContext()
	GameLogic.GetFilters():remove_all_filters("DefaultContext");
	GameLogic.GetFilters():add_filter("DefaultContext", function(context)
	   return FissionContext:new();
	end);
end

-- static method: reset scene context to vanila scene context
function FissionContext:ResetDefaultContext()
	GameLogic.GetFilters():remove_all_filters("DefaultContext");
	GameLogic.ActivateDefaultContext();
end

-- virtual function: 
-- try to select this context. 
function FissionContext:OnSelect()
	FissionContext._super.OnSelect(self);
	self:EnableMousePickTimer(true);
end

-- virtual function: 
-- return true if we are not in the middle of any operation and fire unselected signal. 
-- or false, if we can not unselect the scene tool context at the moment. 
function FissionContext:OnUnselect()
	FissionContext._super.OnUnselect(self);
	return true;
end

function FissionContext:OnLeftLongHoldBreakBlock()
	self:TryDestroyBlock(SelectionManager:GetPickingResult());
end


-- virtual: 
function FissionContext:mousePressEvent(event)
	FissionContext._super.mousePressEvent(self, event);
	if(event:isAccepted()) then
		return
	end

	local click_data = self:GetClickData();
	if(event.ctrl_pressed and GameLogic.GameMode:IsEditor()) then
		NPL.load("(gl)script/apps/Aries/Creator/Game/GUI/ScreenRectSelector.lua");
		local ScreenRectSelector = commonlib.gettable("MyCompany.Aries.Game.GUI.Selectors.ScreenRectSelector");
		click_data.selector = ScreenRectSelector:new():Init(5,5,"left");
		click_data.selector:BeginSelect(function(mode, left, top, width, height)
			NPL.load("(gl)script/apps/Aries/Creator/Game/GUI/ObjectSelectPage.lua");
			local ObjectSelectPage = commonlib.gettable("MyCompany.Aries.Game.GUI.ObjectSelectPage");
			if(mode == "selected") then
				ObjectSelectPage.SelectByScreenRect(left, top, width, height);
			else
				ObjectSelectPage.CloseWindow();
			end
		end)
	else
		click_data.selector = nil;
		self:EnableMouseDownTimer(true);
	end
	
	local result = self:CheckMousePick();
	self:UpdateClickStrength(0, result);

	if(event.mouse_button == "left") then
		-- play touch step sound when left click on an object
		if(result and result.block_id and result.block_id > 0) then
			click_data.last_mouse_down_block.blockX, click_data.last_mouse_down_block.blockY, click_data.last_mouse_down_block.blockZ = result.blockX,result.blockY,result.blockZ;
			local block = block_types.get(result.block_id);
			if(block and result.blockX) then
				block:OnMouseDown(result.blockX,result.blockY,result.blockZ, event.mouse_button);
			end
		end
	end
end

-- virtual: 
function FissionContext:mouseMoveEvent(event)
	FissionContext._super.mouseMoveEvent(self, event);
	if(event:isAccepted()) then
		return
	end
	local result = self:CheckMousePick();
end

function FissionContext:handleLeftClickScene(event, result)
	local click_data = self:GetClickData();
	--_guihelper.MessageBox("enter for click");
	if( self.left_holding_time < 150) then
		if(result and result.obj and (not result.block_id or result.block_id == 0)) then
			-- for scene object selection, blocks has higher selection priority.  
			if(event.alt_pressed and result.entity) then
				-- alt + left button to pick entity to item stack. 
				local item_class = result.entity:GetItemClass();
				if(item_class) then
					local itemStack = item_class:ConvertEntityToItem(result.entity);
					if(itemStack) then
						GameLogic.GetPlayerController():SetBlockInRightHand(itemStack);
					end
				end
			else
				NPL.load("(gl)script/apps/Aries/Creator/Game/Tasks/SelectModelTask.lua");
				local task = MyCompany.Aries.Game.Tasks.SelectModel:new({obj=result.obj})
				task:Run();
			end
		else
			-- for blocks
			--_guihelper.MessageBox("enter for block");
			local is_shift_pressed = event.shift_pressed;
			local ctrl_pressed = event.ctrl_pressed;
			local alt_pressed = event.alt_pressed;

			local is_processed
			if(not is_shift_pressed and not alt_pressed and not ctrl_pressed and result and result.blockX) then
				-- if it is a left click, first try the game logics if it is processed. such as an action neuron block.
				if(result.entity and result.entity:IsBlockEntity() and result.entity:GetBlockId() == result.block_id) then
					-- this fixed a bug where block entity is larger than the block like the physics block model.
					local bx, by, bz = result.entity:GetBlockPos();
					is_processed = GameLogic.GetPlayerController():OnClickBlock(result.block_id, bx, by, bz, event.mouse_button, EntityManager.GetPlayer(), result.side);	
				else
					is_processed = GameLogic.GetPlayerController():OnClickBlock(result.block_id, result.blockX, result.blockY, result.blockZ, event.mouse_button, EntityManager.GetPlayer(), result.side);	
				end
			end
			if(not is_processed) then
				if(alt_pressed and result and result.blockX) then
					-- alt + left click to get the block in hand without destroying it
					if(result.block_id) then
						GameLogic.GetPlayerController():PickBlockAt(result.blockX, result.blockY, result.blockZ);
					end
				elseif(ctrl_pressed and result and result.blockX) then
						--_guihelper.MessageBox("phf Im in");
						worldName = ParaWorld.GetWorldName()
						curWorld = ParaBlockWorld.GetWorld(worldName)
						ret = ParaBlockWorld.SplitBlock(curWorld, click_data.last_select_block.blockX, click_data.last_select_block.blockY, click_data.last_select_block.blockZ, '0')
						echo(ret)
				else
					-- left click to delete the current point
					if(result and result.blockX) then
						if(is_shift_pressed) then
							-- editor mode hold shift key will destroy several blocks. 
							NPL.load("(gl)script/apps/Aries/Creator/Game/Tasks/DestroyNearbyBlocksTask.lua");
							-- just around the player
							local task = MyCompany.Aries.Game.Tasks.DestroyNearbyBlocks:new({blockX=result.blockX, blockY=result.blockY, blockZ=result.blockZ, block_id = result.block_id, explode_time=200, })
							task:Run();
						else
							if(event.dragDist and event.dragDist<15) then
								self:TryDestroyBlock(result);
							end
						end
					end
				end
			end
		end
	elseif( self.left_holding_time > self.max_break_time) then
		if( result and result.blockX ) then
			if( false and result.block_id and result.block_id > 0) then
				-- long hold left click to select the block
				NPL.load("(gl)script/apps/Aries/Creator/Game/Tasks/SelectBlocksTask.lua");
				local task = MyCompany.Aries.Game.Tasks.SelectBlocks:new({blockX = result.blockX,blockY = result.blockY, blockZ = result.blockZ})
				task:Run();
			else
				if(click_data.strength and click_data.strength > self.max_break_time) then
					self:TryDestroyBlock(result, true);	
				end
			end
		else
			-- long hold left click to delete the block
			self:TryDestroyBlock(result, true);
		end
	end
end

-- virtual: 
function FissionContext:mouseReleaseEvent(event)
	FissionContext._super.mouseReleaseEvent(self, event);
	if(event:isAccepted()) then
		return
	end
	local click_data = self:GetClickData();
	if(click_data.selector) then
		if(click_data.selector:OnUpdate() == "selected") then
			self.is_click = nil;
		end
		click_data.selector = nil;
	end

	if(self.is_click) then
		local result = self:CheckMousePick();
		local isClickProcessed;
		
		-- escape alt key for entity event, since alt key is for picking entity. 
		if( not event.alt_pressed and result and result.obj and result.entity and (not result.block_id or result.block_id == 0)) then
			-- for entities. 
			isClickProcessed = GameLogic.GetPlayerController():OnClickEntity(result.entity, result.blockX, result.blockY, result.blockZ, event.mouse_button);
		end

		if(isClickProcessed) then	
			-- do nothing
		elseif(event.mouse_button == "left") then
			self:handleLeftClickScene(event, result);
		elseif(event.mouse_button == "right") then
			self:handleRightClickScene(event, result);
		elseif(event.mouse_button == "middle") then
			self:handleMiddleClickScene(event, result);
		end
	end
end

-- virtual: 
function FissionContext:mouseWheelEvent(event)
	FissionContext._super.mouseWheelEvent(self, event);
	if(event:isAccepted()) then
		return
	end
end

-- virtual: undo/redo related key events, such as ctrl+Z/Y
-- @return true if event is accepted. 
function FissionContext:handleHistoryKeyEvent(event)
	if(GameLogic.GameMode:CanAddToHistory()) then
		local dik_key = event.keyname;
		if(event.shift_pressed) then
			--[[ disabled Shift+W, X, Space to destroy blocks. use shift+left click instead. 
			if(dik_key == "DIK_W") then
				NPL.load("(gl)script/apps/Aries/Creator/Game/Tasks/DestroyNearbyBlocksTask.lua");
				local task = MyCompany.Aries.Game.Tasks.DestroyNearbyBlocks:new({direction="front", detect_key = dik_key})
				task:Run();	
			elseif(dik_key == "DIK_X") then
				NPL.load("(gl)script/apps/Aries/Creator/Game/Tasks/DestroyNearbyBlocksTask.lua");
				local task = MyCompany.Aries.Game.Tasks.DestroyNearbyBlocks:new({direction="down", detect_key = dik_key})
				task:Run();	
			elseif(dik_key == "DIK_SPACE") then
				NPL.load("(gl)script/apps/Aries/Creator/Game/Tasks/DestroyNearbyBlocksTask.lua");
				local task = MyCompany.Aries.Game.Tasks.DestroyNearbyBlocks:new({direction="up", detect_key = dik_key})
				task:Run();	
			end]]
		elseif(dik_key == "DIK_Z" and event.ctrl_pressed) then
			if(GameMode:IsAllowGlobalEditorKey()) then
				UndoManager.Undo();
				event:accept();
			end
		elseif(dik_key == "DIK_Y" and event.ctrl_pressed) then
			if(GameMode:IsAllowGlobalEditorKey()) then
				UndoManager.Redo();
				event:accept();
			end
		end
	end
	return event:isAccepted();
end

-- virtual: actually means key stroke. 
function FissionContext:keyPressEvent(event)
	FissionContext._super.keyPressEvent(self, event);
	if(event:isAccepted()) then
		return
	end
	
	if( self:handleHistoryKeyEvent(event) or
		self:handlePlayerKeyEvent(event)) then
		return;
	end
	event:accept();
end
