--[[
Title: DemoItem
Author(s):  phf
Date: 2017.04.10
Desc: a fissionable block item
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/fissionable_block/ItemFissionable.lua");
local DemoItem = commonlib.gettable("Mod.Fissionable.ItemFissionable");
------------------------------------------------------------
]]

local block_types = commonlib.gettable("MyCompany.Aries.Game.block_types")
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic")
local ItemStack = commonlib.gettable("MyCompany.Aries.Game.Items.ItemStack");

local ItemFission = commonlib.inherit(commonlib.gettable("MyCompany.Aries.Game.Items.ItemToolBase"),commonlib.gettable("Mod.Fissionable.ItemFissionable"));

block_types.RegisterItemClass("ItemFissionable", ItemFission);

local current_block_status = nil;

function ItemFission:ctor()
	self.PageCtrl = nil;
end

function ItemFission:init()
	LOG.std(nil, "info", "DemoItem", "init");

	-- register a new block item, id < 10512 is internal items, which is not recommended to modify. 
	GameLogic.GetFilters():add_filter("block_types", function(xmlRoot) 
		local blocks = commonlib.XPath.selectNode(xmlRoot, "/blocks/");
		if(blocks) then
			blocks[#blocks+1] = {name="block", attr={
				id = 520,
				item_class="ItemFissionable",
				text="可分裂方块",
				name="ItemFissionable",
				icon = "Texture/blocks/bookshelf_three.png",
				threeSideTex = "true",
				texture="Texture/blocks/bookshelf_three.png",
				obstruction="true",
				solid="true",
				cubeMode="true",
				modelName="split",
			}}
			LOG.std(nil, "info", "ItemFissionable", "ItemFissionable block is registered");
		end
		return xmlRoot;
	end)

	-- add block to category list to be displayed in builder window (E key)
	GameLogic.GetFilters():add_filter("block_list", function(xmlRoot) 
		for node in commonlib.XPath.eachNode(xmlRoot, "/blocklist/category") do
			if(node.attr.name == "tool") then
				node[#node+1] = {name="block", attr={name="ItemFissionable"} };
			end
		end
		return xmlRoot;
	end)
end

function ItemFission:ShowPropertyPage()
	local page = commonlib.getfield("ItemFission.PropertyPage");
	if(not page) then
		print("phf i'm in");
		NPL.load("(gl)script/kids/3DMapSystemApp/mcml/PageCtrl.lua");
        page = Map3DSystem.mcml.PageCtrl:new({url="Mod/fissionable_block/property.html"});
        commonlib.setfield("ItemFission.PropertyPage", page);
        page:Create("ItemFission.PropertyPage", nil, "_ctb", 0, -50, 250, 250);
        --ParaUI.GetUIObject("ItemFission.PropertyPage").zorder = 1002;
	end
end

function ItemFission:TryCreate(itemStack, entityPlayer, x,y,z, side, data, side_region)
	--_guihelper.MessageBox("test");
	if(not current_block_status) then
		self:ShowPropertyPage();
		--return;
	end

	if (itemStack and itemStack.count == 0) then
		return;
	elseif (entityPlayer and not entityPlayer:CanPlayerEdit(x,y,z, data, itemStack)) then
		return;
	elseif (self:CanPlaceOnSide(x,y,z,side, data, side_region, entityPlayer, itemStack)) then
		-- 4096 is hard coded
		if(self.id and self.id > 4096) then
			if(not self.max_count or self:GetInWorldCount() < self.max_count) then
				local facing;
				if(self:HasFacing()) then
					facing =  ParaScene.GetPlayer():GetFacing();
				end
				local bCreated, entityCreated = self:OnCreate({blockX = x, blockY = y, blockZ = z, facing = facing, side=side, itemStack = itemStack});
				if(bCreated and itemStack) then
					itemStack.count = itemStack.count - 1;
				end
				return true, entityCreated;
			else
				if(self.max_count == 1) then
					-- move it if there is only one. 
					local entities = EntityManager.GetEntitiesByItemID(self.id);
					if(entities) then
						entities[1]:SetBlockPos(x,y,z);
					else
						self:OnCreate({blockX = x, blockY = y, blockZ = z, facing = 0, side=side});
					end
					return true;
				else
					_guihelper.MessageBox(string.format("世界中最多可以放置%d个[%s]. 已经超出上限", self.max_count or 0,  self.text or ""));
				end
			end
		else
			local block_id = self.block_id;
			local block_template = block_types.get(block_id);
			echo("phf ---------------------- ")
			echo(block_id)
			echo(block_template)
			echo("phf ---------------------- end")
			if(block_template) then
				data = data or block_template:GetMetaDataFromEnv(x, y, z, side, side_region);
				echo(data)
				--[[
				if(BlockEngine:SetBlock(x, y, z, block_id, data, 3)) then
					block_template:play_create_sound();
					_guihelper.MessageBox("fsdds");
					block_template:OnBlockPlacedBy(x,y,z, entityPlayer);
					if(itemStack) then
						itemStack.count = itemStack.count - 1;
					end
				end]]
				ParaTerrain.SetBlockTemplateByIdx(x,y,z,block_id);
				return true;
			end
		end
	end
end

-- called whenever this item is clicked on the user interface when it is holding in hand of a given player (current player). 
function ItemFission:OnClickInHand(itemStack, entityPlayer)
	--_guihelper.MessageBox("sdsdsd");
end

-- virtual function: when selected in right hand
function ItemFission:OnSelect(itemStack)
	ItemFission._super.OnSelect(self, itemStack);
	--GameLogic.SetStatus(L"-_- !!");
end

function ItemFission:OnDeSelect()
	ItemFission._super.OnDeSelect(self);
	local page = commonlib.getfield("ItemFission.PropertyPage");
	if(page) then 
		page:Close();
		--echo(page);
	end
	commonlib.setfield("ItemFission.PropertyPage", nil);
	GameLogic.SetStatus(nil);
end

-- virtual: draw icon with given size at current position (0,0)
-- @param width, height: size of the icon
-- @param itemStack: this may be nil. or itemStack instance. 
function ItemFission:DrawIcon(painter, width, height, itemStack)
	ItemFission._super.DrawIcon(self, painter, width, height, itemStack);
	local filename = self:GetModelFileName(itemStack);
	if(filename and filename~="") then
		filename = filename:match("[^/]+$"):gsub("%..*$", "");
		filename = filename:sub(1, 6);
		painter:SetPen("#33333380");
		painter:DrawRect(0,0, width, 14);
		painter:SetPen("#ffffff");
		painter:DrawText(1,0, filename);
	end
end

-- virtual function: 
function ItemFission:CreateTask(itemStack)
	--print("phf -- task created");
	NPL.load("(gl)Mod/fissionable_block/SetPropertyTask.lua");
	local SetPropertyTask = commonlib.gettable("MyCompany.Aries.Game.Tasks.SetPropertyTask");
	local task = SetPropertyTask:new();
	task:SetItemStack(itemStack);
	return task;
end

function ItemFission.GetTextureList()
	local texture_table = {
		{text="香蕉皮",value="banana_skin"},
		{text="西瓜皮",value="water_mellon_skin"},
	};
	return texture_table;
end