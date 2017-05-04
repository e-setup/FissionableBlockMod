--[[
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/NPLCAD/SetPropertyTask.lua");
local SetPropertyTask = commonlib.gettable("MyCompany.Aries.Game.Tasks.SetPropertyTask");
local task = SetPropertyTask:new();
task:Run();
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/Tasks/UndoManager.lua");
NPL.load("(gl)script/ide/math/vector.lua");
NPL.load("(gl)script/ide/System/Windows/Keyboard.lua");
NPL.load("(gl)Mod/fissionable_block/FissionContext.lua");

local FissionContext = commonlib.gettable("Mod.FissionableBlock.FissionContext");
local Keyboard = commonlib.gettable("System.Windows.Keyboard");
local UndoManager = commonlib.gettable("MyCompany.Aries.Game.UndoManager");
local vector3d = commonlib.gettable("mathlib.vector3d");
local BlockEngine = commonlib.gettable("MyCompany.Aries.Game.BlockEngine")
local block_types = commonlib.gettable("MyCompany.Aries.Game.block_types")
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic")
local EntityManager = commonlib.gettable("MyCompany.Aries.Game.EntityManager");

local SetPropertyTask = commonlib.inherit(commonlib.gettable("MyCompany.Aries.Game.Task"), commonlib.gettable("MyCompany.Aries.Game.Tasks.SetPropertyTask"));

SetPropertyTask:Property({"LeftLongHoldToDelete", false, auto=true});

local curInstance;

-- this is always a top level task. 
SetPropertyTask.is_top_level = true;

function SetPropertyTask:ctor()
	self.position = vector3d:new(0,0,0);
	self.transformMode = false;
	self.sceneContext = FissionContext;
end

function SetPropertyTask:SetItemStack(itemStack)
	self.itemStack = itemStack;
end

function SetPropertyTask:GetItemStack()
	return self.itemStack;
end

local page;
function SetPropertyTask.InitPage(Page)
	page = Page;
end

-- get current instance
function SetPropertyTask.GetInstance()
	return curInstance;
end

function SetPropertyTask.OnClickEditCadScript()
	local self = SetPropertyTask.GetInstance();
	local item = self:GetItem();
	if(item) then
		item:OpenEditor(self:GetItemStack());
	end
end

function SetPropertyTask.OnClickChangeCadScript()
	local self = SetPropertyTask.GetInstance();
	local item = self:GetItem();
	if(item) then
		item:OnClickInHand(self:GetItemStack(), EntityManager.GetPlayer());
	end
end

function SetPropertyTask:GetItem()
	local itemStack = self:GetItemStack();
	if(itemStack) then
		return itemStack:GetItem();
	end
end

function SetPropertyTask:GetCadScript()
	local item = self:GetItem();
	if(item) then
		return item:GetModelFileName(self:GetItemStack()) or "";
	end
end

function SetPropertyTask:RefreshPage()
	if(page) then
		page:Refresh(0.01);
	end
end

function SetPropertyTask:Run()
	curInstance = self;
	self.finished = false;
	--_guihelper.MessageBox("fdfdfhdjfkdh js phf 2");
	FissionContext:ApplyToDefaultContext();
	self:LoadSceneContext();
	--self:GetSceneContext():setMouseTracking(true);
	--self:GetSceneContext():setCaptureMouse(true);
	--self:ShowPage();
end

function SetPropertyTask:OnExit()
	self:SetFinished();
	FissionContext:ResetDefaultContext();
	self:UnloadSceneContext();
	--self:CloseWindow();
	curInstance = nil;
end

function SetPropertyTask:SelectModel(entityModel)
	if(self.entityModel~=entityModel) then
		self.entityModel = entityModel;
		self:UpdateManipulators();
	end
end

function SetPropertyTask:GetSelectedModel()
	return self.entityModel;
end

function SetPropertyTask:UpdateManipulators()
	self:DeleteManipulators();

	if(self.entityModel) then
		NPL.load("(gl)Mod/NPLCAD/EditCadManipContainer.lua");
		local EditCadManipContainer = commonlib.gettable("MyCompany.Aries.Game.Manipulators.EditCadManipContainer");
		local manipCont = EditCadManipContainer:new();
		manipCont:init();
		self:AddManipulator(manipCont);
		manipCont:connectToDependNode(self.entityModel);

		self:RefreshPage();
	end
end

function SetPropertyTask:Redo()
end

function SetPropertyTask:Undo()
end

function SetPropertyTask:ShowPage()
--[[
	local window = self:CreateGetToolWindow();
	window:Show({
		name="SetPropertyTask", 
		url="Mod/fissionable_block/property.html",
		alignment="_ctb", left=0, top=-20, width = 256, height = 64,
	});]]
	--[[System.App.Commands.Call("File.MCMLWindowFrame", {
		url  = "Mod/fissionable_block/property.html", 
		name = "SetPropertyTask", 
		isShowTitleBar = true,
		DestroyOnClose = true, -- prevent many ViewProfile pages staying in memory / false will only hide window
		style = CommonCtrl.WindowFrame.ContainerStyle,
		zorder = 0,
		allowDrag = true,
		bShow = true,
		directPosition = true,
			align = "_ctb",
			x = 0,
			y = -50,
			width = 250,
			height = 100,
		cancelShowAnimation = true,
	});]]
end


-- @param result: can be nil
function SetPropertyTask:PickModelAtMouse(result)
	local result = result or Game.SelectionManager:MousePickBlock(true, true, false);
	if(result.blockX) then
		local x,y,z = result.blockX,result.blockY,result.blockZ;
		local modelEntity = BlockEngine:GetBlockEntity(x,y,z) or result.entity;
		if(modelEntity and modelEntity:isa(EntityManager.EntityBlockModel)) then
			return modelEntity;
		end
	end
end

function SetPropertyTask:OnLeftLongHoldBreakBlock()
	local modelEntity = self:PickModelAtMouse()
	if(modelEntity) then
		self:GetSceneContext():TryDestroyBlock(Game.SelectionManager:GetPickingResult());
	end
end

function SetPropertyTask:handleLeftClickScene(event, result)
	local modelEntity = self:PickModelAtMouse();
	if(modelEntity) then
		self:SelectModel(modelEntity);
	end
end

function SetPropertyTask:handleRightClickScene(event, result)
	local modelEntity = self:PickModelAtMouse();
	if(modelEntity) then
		modelEntity:OpenEditor("entity", modelEntity);
	else
		-- create model here 
		local item = self:GetItem();
		if(item) then
			local side = BlockEngine:GetOppositeSide(result.side);
			local x, y, z = BlockEngine:GetBlockIndexBySide(result.blockX,result.blockY,result.blockZ, result.side);
			local task = MyCompany.Aries.Game.Tasks.CreateBlock:new({blockX = x,blockY = y, blockZ = z, entityPlayer = EntityManager.GetPlayer(), 
				itemStack = self:GetItemStack(), block_id = item.id});
			task:Run();
			-- item:TryCreate(self:GetItemStack(), EntityManager.GetPlayer(), x,y,z,side);
		end
	end
end

function SetPropertyTask:mousePressEvent(event)
	self:GetSceneContext():mousePressEvent(event);
	if(self:GetLeftLongHoldToDelete()) then
		self:GetSceneContext():EnableMouseDownTimer(true);
	end
end

function SetPropertyTask:mouseMoveEvent(event)
	self:GetSceneContext():mouseMoveEvent(event);
end

function SetPropertyTask:mouseWheelEvent(event)
	self:GetSceneContext():mouseWheelEvent(event);
end

function SetPropertyTask:keyPressEvent(event)
	local dik_key = event.keyname;
	if(dik_key == "DIK_ADD" or dik_key == "DIK_EQUALS") then
		-- increase scale
		
	elseif(dik_key == "DIK_SUBTRACT" or dik_key == "DIK_MINUS") then
		-- decrease scale
		
	elseif(dik_key == "DIK_Z")then
		UndoManager.Undo();
	elseif(dik_key == "DIK_Y")then
		UndoManager.Redo();
	end
	self:GetSceneContext():keyPressEvent(event);
end
