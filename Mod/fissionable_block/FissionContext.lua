
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
NPL.load("(gl)script/ide/System/Core/SceneContext.lua");
NPL.load("(gl)script/ide/Storyboard/Storyboard.lua");
NPL.load("(gl)script/ide/Display3D/SceneManager.lua");
NPL.load("(gl)script/ide/Display3D/SceneNode.lua");

local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic")
local SelectionManager = commonlib.gettable("MyCompany.Aries.Game.SelectionManager");
local ModManager = commonlib.gettable("Mod.ModManager");
local CameraController = commonlib.gettable("MyCompany.Aries.Game.CameraController")
local EntityManager = commonlib.gettable("MyCompany.Aries.Game.EntityManager");


local FissionContext = commonlib.inherit(commonlib.gettable("MyCompany.Aries.Game.SceneContext.BaseContext"), commonlib.gettable("Mod.FissionableBlock.FissionContext"));
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

function FissionContext:handleHookedMouseEvent(event)
	if(ModManager:handleMouseEvent(event)) then
		return true;
	end

	if(self:handleItemMouseEvent(event)) then
		return true;
	end
	return event:isAccepted();
end


function FissionContext:mouseMoveEvent(event)
	FissionContext._super.mouseMoveEvent(self, event);
	if(event:isAccepted()) then
		return
	end
end

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
			self:handleLeftClickScene(event,result);
		end
	end
end

function FissionContext:mouseWheelEvent(event)
--[[
	local CameraObjectDistance = ParaCamera.GetAttributeObject():GetField("CameraObjectDistance", 8);
	CameraObjectDistance = CameraObjectDistance - mouse_wheel * CameraObjectDistance * 0.1;
	CameraObjectDistance = math.max(2, math.min(CameraObjectDistance, 20));
	ParaCamera.GetAttributeObject():SetField("CameraObjectDistance", CameraObjectDistance);]]
end

function FissionContext:keyReleaseEvent(event)
end

function FissionContext:keyPressEvent(event)
	if(ModManager:handleMouseEvent(event)) then
		return true;
	end
	return event:isAccepted();
end

function FissionContext:OnSelect()
end

function FissionContext:OnUnselect()
end

function FissionContext:mousePressEvent(event)
	FissionContext._super.mousePressEvent(self, event);
	if(event.mouse_button == "left") then
		--print("phf --- left button down");
		local result = self:CheckMousePick();
		if(result and result.entity) then
			return

		end
		self.left_button_down = true;
		self.currentY = event.y;
	end
	if(event:isAccepted()) then
		return
	end
end

-- this function is called repeatedly if MousePickTimer is enabled. 
-- it can also be called independently. 
-- @return the picking result table
function FissionContext:CheckMousePick()
	if(self.mousepick_timer) then
		self.mousepick_timer:Change(50, nil);
	end

	local result = SelectionManager:MousePickBlock();

	if(self:GetEditMarkerBlockId() and result and result.block_id and result.block_id>0 and result.blockX) then
		local y = BlockEngine:GetFirstBlock(result.blockX, result.blockY, result.blockZ, self:GetEditMarkerBlockId(), 5);
		if(y<0) then
			-- if there is no helper blocks below the picking position, we will return nothing. 
			SelectionManager:ClearPickingResult();
			self:ClearPickDisplay();
			return;
		end
	end

	CameraController.OnMousePick(result, SelectionManager:GetPickingDist());
	
	if(result.length and result.blockX) then
		if(not EntityManager.GetFocus():CanReachBlockAt(result.blockX,result.blockY,result.blockZ)) then
			SelectionManager:ClearPickingResult();
		end
	end
	
	-- highlight the block or terrain that the mouse picked
	if(result.length and result.length<SelectionManager:GetPickingDist() and GameLogic.GameMode:CanSelect()) then
		self:HighlightPickBlock(result);
		self:HighlightPickEntity(result);
	else
		self:ClearPickDisplay();
	end
end

function FissionContext:handleLeftClickScene(event, result)
	local click_data = self:GetClickData();
	echo(click_data)
	if(event.ctrl_pressed) then
		--_guihelper.MessageBox("phf Im in");
		worldName = ParaWorld.GetWorldName()
		curWorld = ParaBlockWorld.GetWorld(worldName)
		ret = ParaBlockWorld.SplitBlock(curWorld, click_data.last_select_block.blockX, click_data.last_select_block.blockY, click_data.last_select_block.blockZ, '0')
		echo(ret)
	end
end