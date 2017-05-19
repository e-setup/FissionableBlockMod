
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
NPL.load("(gl)Mod/fissionable_block/ItemFissionable.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Tasks/CreateFissionableBlockTask.lua");
NPL.load("(gl)Mod/fissionable_block/BlockFissionTask.lua");

local ItemFissionable = commonlib.gettable("Mod.Fissionable.ItemFissionable");
local UndoManager = commonlib.gettable("MyCompany.Aries.Game.UndoManager");
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic")
local GameMode = commonlib.gettable("MyCompany.Aries.Game.GameLogic.GameMode");
local EntityManager = commonlib.gettable("MyCompany.Aries.Game.EntityManager");
local block_types = commonlib.gettable("MyCompany.Aries.Game.block_types")
local BlockEngine = commonlib.gettable("MyCompany.Aries.Game.BlockEngine")
local FissionContext = commonlib.inherit(commonlib.gettable("MyCompany.Aries.Game.SceneContext.BaseContext"), commonlib.gettable("Mod.FissionableBlock.FissionContext"));

FissionContext:Property("Name", "FissionContext");

local current_block_status = nil;
local page = nil;

function FissionContext:ctor()
	self:EnableAutoCamera(true);
end

function FissionContext:ShowPropertyPage(status)
	if(not page) then
		NPL.load("(gl)script/kids/3DMapSystemApp/mcml/PageCtrl.lua");
        page = Map3DSystem.mcml.PageCtrl:new({url="Mod/fissionable_block/property.html",allowDrag=true});
        page:Create("ItemFission.PropertyPage", nil, "_ctb", 0, -50, 250, 250);
	end
	if(status) then
		current_block_status = status;
	end
	if(current_block_status) then
		local color = string.format("%d %d %d", current_block_status.color.r,
		 current_block_status.color.g, current_block_status.color.b);
		--print("phf I am in ShowPropertyPage:"..color);
		--echo(page);
	end
end


function FissionContext:GetCurrentColor()
	if(current_block_status) then
		local color = string.format("%d %d %d", current_block_status.color.r,
		 current_block_status.color.g, current_block_status.color.b);
		--print("phf I am in ShowPropertyPage:"..color);
		return color;
	end
	return "255 255 255";
end

function FissionContext:GetCurrentBlockStatus()
	if(current_block_status) then
		return current_block_status;
	end
	return nil;
end

function FissionContext:ClosePropertyPage()
    local target_block = commonlib.getfield("Mod.Fissionable.target_block");
    if(target_block) then
        local worldName = ParaWorld.GetWorldName();
		local curWorld = ParaBlockWorld.GetWorld(worldName);
		if(target_block.type == 0) then
			local r,g,b = current_block_status.color.r,current_block_status.color.g,current_block_status.color.b;
			local color = math.ldexp(r, 16)+math.ldexp(g, 8)+b+math.ldexp(15,24);
            ParaBlockWorld.SetBlockColor(curWorld,target_block.position.x,target_block.position.y,target_block.position.z,target_block.level,color);
        else -- !!TODO:设置纹理未完成
            ParaBlockWorld.SetBlockTexture(curWorld,target_block.position.x,target_block.position.y,target_block.position.z,target_block.level,"");
		end
    end
	commonlib.setfield("Mod.Fissionable.target_block",nil);
	page = nil;
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
						local BlockFissionTask = commonlib.gettable("MyCompany.Aries.Game.Tasks.BlockFissionTask");
						local param = {
							action = "split",
							blockX = result.blockX,
							blockY = result.blockY,
							blockZ = result.blockZ,
							data=nil,
							side = result.side,
							side_region=result.side_region,
							block_id = result.block_id,
							entityPlayer=EntityManager.GetPlayer(),
							itemStack=nil
						};
						local task = BlockFissionTask:new(param);
						task:Run();
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
								local BlockFissionTask = commonlib.gettable("MyCompany.Aries.Game.Tasks.BlockFissionTask");
								local task = BlockFissionTask:new(
								{
									action = "destory",
									blockX = result.blockX,
									blockY = result.blockY,
									blockZ = result.blockZ,
									data=nil,
									side = result.side,
									side_region=result.side_region,
									block_id = result.block_id,
									entityPlayer=EntityManager.GetPlayer(),
									itemStack=nil
								})
								task:Run();
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

function FissionContext:handleRightClickScene(event, result)
	result = result or SelectionManager:GetPickingResult();
	local click_data = self:GetClickData();
	local isProcessed;
	if(not isProcessed and result and result.blockX) then
		if(click_data.right_holding_time<400) then
			if(not event.shift_pressed and not event.alt_pressed and not event.ctrl_pressed and result.block_id and result.block_id>0) then
				-- if it is a right click, first try the game logics if it is processed. such as an action neuron block.
				if(result.entity and result.entity:IsBlockEntity() and result.entity:GetBlockId() == result.block_id) then
					-- this fixed a bug where block entity is larger than the block like the physics block model.
					local bx, by, bz = result.entity:GetBlockPos();
					isProcessed = GameLogic.GetPlayerController():OnClickBlock(result.block_id, bx, by, bz, event.mouse_button, EntityManager.GetPlayer(), result.side);
				else
					isProcessed = GameLogic.GetPlayerController():OnClickBlock(result.block_id, result.blockX, result.blockY, result.blockZ, event.mouse_button, EntityManager.GetPlayer(), result.side);
				end
			elseif(event.ctrl_pressed and result and result.blockX) then
				local target_block = {};
				target_block.position= {x=result.blockX,y=result.blockY,z=result.blockZ};
				--!!TODO:获取当前方块是使用贴图还是颜色
				target_block.type = 0; -- 贴图暂未实现 目前写定为使用颜色
				--local bit = require "bit";
				
				local worldName = ParaWorld.GetWorldName();
				local curWorld = ParaBlockWorld.GetWorld(worldName);
				
				target_block.level = ParaBlockWorld.GetBlockSplitLevel(curWorld,result.blockX,result.blockY,result.blockZ);
				local color = ParaBlockWorld.GetBlockColor(curWorld,result.blockX,result.blockY,result.blockZ,target_block.level);
				--print("phf getblockcolor = "..color);
				--color = 0x00010203;
				local b = bit.band(color,0x000000ff);
				local g = bit.band(bit.rshift(color, 8),0x000000ff);
				local r = bit.band(bit.rshift(color, 16),0x000000ff);
				--print(string.format("%d %d %d",r,g,b));
				self:SetProperty({type=0,color={r=r,g=g,b=b}});
				commonlib.setfield("Mod.Fissionable.target_block",target_block);
				self:ShowPropertyPage({type=0,color={r=r,g=g,b=b}});
				isProcessed = true;
			end
		end
	end
	if(not isProcessed and click_data.right_holding_time<400) then
		local player = EntityManager.GetPlayer();
		if(player) then
			local itemStack = player.inventory:GetItemInRightHand();
			if(itemStack) then
				local newStack, hasHandled = itemStack:OnItemRightClick(player);
				if(hasHandled) then
					isProcessed = hasHandled;
				end
			end
		end
	end
	if(not isProcessed and click_data.right_holding_time<400 and result and result.blockX) then
		if(GameMode:CanRightClickToCreateBlock()) then
			if(not current_block_status) then
				self:ShowPropertyPage();
				return;
			end
			local x,y,z = BlockEngine:GetBlockIndexBySide(result.blockX,result.blockY,result.blockZ,result.side);
			local itemStack = EntityManager.GetPlayer():GetItemInRightHand();
			local block_id = 0;
			local block_data = nil;
			if(itemStack) then
				block_id = itemStack.id;
				local item = itemStack:GetItem();
				if(item) then
					block_data = item:GetBlockData(itemStack);
				else
					LOG.std(nil, "debug", "BaseContext", "no block definition for %d", block_id or 0);
					return;
				end
			end
			local side_region;
			if(result.y) then
				if(result.side == 4) then
					side_region = "upper";
				elseif(result.side == 5) then
					side_region = "lower";
				else
					local _, center_y, _ = BlockEngine:real(0,result.blockY,0);
					if(result.y > center_y) then
						side_region = "upper";
					elseif(result.y < center_y) then
						side_region = "lower";
					end
				end
			end
			local param = {blockX = x,blockY = y, blockZ = z, entityPlayer = EntityManager.GetPlayer(), block_id = 520, side = result.side, from_block_id = result.block_id, side_region=side_region,current_block_status = current_block_status};
			NPL.load("(gl)Mod/fissionable_block/CreateFissionableBlockTask.lua");
			local CreateFissionableBlockTask = commonlib.gettable("MyCompany.Aries.Game.Tasks.CreateFissionableBlock");
			local task = CreateFissionableBlockTask:new(param);
			task:SetItemStack(itemStack);
			task:Run();
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

function FissionContext:GetTextureList()
	local texture_table = {
		{text="香蕉皮",value="banana_skin"},
		{text="西瓜皮",value="water_mellon_skin"},
	};
	return texture_table;
end

--需要传入{type=0|1,color=value,textureid=id}
function FissionContext:SetProperty(property)
	if(property) then
		if(property.type and property.type ~= 0) then
			_guihelper.MessageBox("暂时不支持纹理贴图设置!");
			current_block_status = nil;
			return;
		end
		current_block_status = property;
		--echo(current_block_status)
	else
		_guihelper.MessageBox("参数有误!");
	end
end