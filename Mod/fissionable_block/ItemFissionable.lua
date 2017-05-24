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

NPL.load("(gl)Mod/fissionable_block/FissionContext.lua");

local block_types = commonlib.gettable("MyCompany.Aries.Game.block_types")
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic")
local ItemStack = commonlib.gettable("MyCompany.Aries.Game.Items.ItemStack");
local FissionContext = commonlib.gettable("Mod.FissionableBlock.FissionContext");

local ItemFission = commonlib.inherit(commonlib.gettable("MyCompany.Aries.Game.Items.ItemToolBase"),commonlib.gettable("Mod.Fissionable.ItemFissionable"));

block_types.RegisterItemClass("ItemFissionable", ItemFission);

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

function ItemFission:TryCreate(itemStack, entityPlayer, x,y,z, side, data, side_region)
	if (itemStack and itemStack.count == 0) then
	end
	if (entityPlayer and not entityPlayer:CanPlayerEdit(x,y,z, data, itemStack)) then
	end
	local canPlace = self:CanPlaceOnSide(x,y,z,side, data, side_region, entityPlayer, itemStack);
	--echo(canPlace)
	local param = {x=x,y=y,z=z,side=side, data=data, side_region=side_region, itemStack=itemStack}
	--echo(param);
	if (true) then
		--_guihelper.MessageBox("pghf Im in");
		local block_id = self.block_id;
		local block_template = block_types.get(block_id);
		--echo(block_template)
		if(block_template) then
			--_guihelper.MessageBox(string.format("pghf Im in2 ,x=%f,y=%f,z=%f",x,y,z));
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
			
			local current_block_status = self.current_block_status;--FissionContext.GetCurrentBlockStatus();
			if(not current_block_status) then
				return false;
			end
			ParaTerrain.SetBlockTemplateByIdx(x,y,z,block_id);
			print("phf current_block_status");
			echo(current_block_status)
			self:ApplyProperty(x,y,z,block_id,"",current_block_status);
			return true;
		end
	else
		_guihelper.MessageBox("can not create")
	end
end

--call to apply the color/texture to the block
function ItemFission:ApplyProperty(x,y,z,block_id,level,current_block_status)
	local worldName = ParaWorld.GetWorldName();
	local curWorld = ParaBlockWorld.GetWorld(worldName);
	local r,g,b = current_block_status.color.r,current_block_status.color.g,current_block_status.color.b;
	local color = math.ldexp(r, 16)+math.ldexp(g, 8)+b+math.ldexp(255,24);
	ParaBlockWorld.SetBlockTexture(curWorld, x, y,z,level,current_block_status.template_id);
	local ret = ParaBlockWorld.SetBlockColor(curWorld, x, y,z,level,color);
end

-- called whenever this item is clicked on the user interface when it is holding in hand of a given player (current player). 
function ItemFission:OnClickInHand(itemStack, entityPlayer)
	FissionContext:ShowPropertyPage();
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
	NPL.load("(gl)Mod/fissionable_block/SwitchToFissionableBlockTask.lua");
	local SwitchToFissionableBlockTask = commonlib.gettable("MyCompany.Aries.Game.Tasks.SwitchToFissionableBlockTask");
	local task = SwitchToFissionableBlockTask:new();
	task:SetItemStack(itemStack);
	return task;
end
