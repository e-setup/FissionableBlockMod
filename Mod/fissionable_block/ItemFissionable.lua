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
local page = nil;

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
				icon = "Texture/blocks/snow.png",
				threeSideTex = "true",
				texture="Texture/blocks/snow.png",
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
	if(not page) then
		NPL.load("(gl)script/kids/3DMapSystemApp/mcml/PageCtrl.lua");
        page = Map3DSystem.mcml.PageCtrl:new({url="Mod/fissionable_block/property.html",allowDrag=true});
        page:Create("ItemFission.PropertyPage", nil, "_ctb", 0, -50, 250, 250);
	end
	if(current_block_status) then
		local color = string.format("%d %d %d", current_block_status.color.r,
		 current_block_status.color.g, current_block_status.color.b);
		--print("phf I am in ShowPropertyPage:"..color);
		--echo(page);
	end
end

function ItemFission:GetCurrentColor()
	if(current_block_status) then
		local color = string.format("%d %d %d", current_block_status.color.r,
		 current_block_status.color.g, current_block_status.color.b);
		--print("phf I am in ShowPropertyPage:"..color);
		return color;
	end
	return "255 255 255";
end

function ItemFission:ClosePropertyPage()
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
	commonlib.getfield("Mod.Fissionable.target_block",nil);
	page = nil;
end

function ItemFission:TryCreate(itemStack, entityPlayer, x,y,z, side, data, side_region)
	--_guihelper.MessageBox("test");
	if(not current_block_status) then
		self:ShowPropertyPage();
		return;
	end

	if (itemStack and itemStack.count == 0) then
		return;
	elseif (entityPlayer and not entityPlayer:CanPlayerEdit(x,y,z, data, itemStack)) then
		return;
	elseif (self:CanPlaceOnSide(x,y,z,side, data, side_region, entityPlayer, itemStack)) then
		local block_id = self.block_id;
		local block_template = block_types.get(block_id);
		if(block_template) then
			data = data or block_template:GetMetaDataFromEnv(x, y, z, side, side_region);
			--echo(data)
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
			local worldName = ParaWorld.GetWorldName();
			local curWorld = ParaBlockWorld.GetWorld(worldName);
			if(current_block_status.type == 0) then
				--echo(current_block_status);
				local r,g,b = current_block_status.color.r,current_block_status.color.g,current_block_status.color.b;
				local color = math.ldexp(r, 16)+math.ldexp(g, 8)+b+math.ldexp(15,24);
				local ret = ParaBlockWorld.SetBlockColor(curWorld, x, y,z,"",color);
			end
			return true;
		end
	end
end

-- called whenever this item is clicked on the user interface when it is holding in hand of a given player (current player). 
function ItemFission:OnClickInHand(itemStack, entityPlayer)
	self:ShowPropertyPage();
end

-- virtual function: when selected in right hand
function ItemFission:OnSelect(itemStack)
	ItemFission._super.OnSelect(self, itemStack);
	GameLogic.SetStatus(L"点击左键消除，按住ctrl+左键进行分裂，按住ctrl+右键设置属性，点击工具栏item设置默认方块属性");
end

function ItemFission:OnDeSelect()
	ItemFission._super.OnDeSelect(self);
	if(page) then 
		page:Close();
	end
	current_block_status = nil;
	page = nil;
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

--需要传入{type=0|1,color=value,textureid=id}
function ItemFission.SetProperty(property)
	if(property) then
		if(property.type and property.type ~= 0) then
			_guihelper.MessageBox("暂时不支持纹理贴图设置!");
			current_block_status = nil;
			return;
		end
		current_block_status = property;
	else
		_guihelper.MessageBox("参数有误!");
	end
end