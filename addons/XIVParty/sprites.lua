--[[
* Copyright (c) 2023 tirem [github.com/tirem] under the GPL-3.0 license
]]--

require('common')
local d3d8 = require('d3d8');
local ffi = require('ffi');
local d3d8_device = d3d8.get_device();

local imageCache = {};

local sprites = {};

local function CreateSprite()
	local sprite_ptr = ffi.new('ID3DXSprite*[1]');
	if (ffi.C.D3DXCreateSprite(d3d8_device, sprite_ptr) ~= ffi.C.S_OK) then
		error('failed to make sprite obj');
	end
	sprites.sprite = d3d8.gc_safe_release(ffi.cast('ID3DXSprite*', sprite_ptr[0]));
end	

local function load_image_from_path(path)

	-- retrieve cached image
	if (imageCache[path] ~= nil) then
		return imageCache[path][1], imageCache[path][2], imageCache[path][3];
	end

    local supports_alpha = false;

    if (path == nil or path == '' or not ashita.fs.exists(path)) then
        return nil, 0, 0;
    end

    local dx_texture_ptr = ffi.new('IDirect3DTexture8*[1]');
	local imageInfo = ffi.new('D3DXIMAGE_INFO');

	local returnImage = nil;
    if (supports_alpha) then
        -- use the native transaparency
        if (ffi.C.D3DXCreateTextureFromFileA(d3d8_device, path, dx_texture_ptr) == ffi.C.S_OK) then
            returnImage = d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', dx_texture_ptr[0]));
        end
    else
        -- use black as colour-key for transparency
        if (ffi.C.D3DXCreateTextureFromFileExA(d3d8_device, path, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0, ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 0xFF000000, imageInfo, nil, dx_texture_ptr) == ffi.C.S_OK) then
            returnImage = d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', dx_texture_ptr[0]));
        end
    end

	-- cache our image and return if it's valid
	if (returnImage ~= nil) then
		imageCache[path] = {returnImage, imageInfo.Width, imageInfo.Height};
		return returnImage, imageInfo.Width, imageInfo.Height
	else
    	return nil, 0, 0;
	end
end

-- reset the icon cache and release all resources
function sprites:SetPath(NewPath)
    self.texture, self.width, self.height = load_image_from_path(NewPath);
	if (self.texture ~= nil and self.sprite == nil) then
		CreateSprite();
	end
end

local function hex2argb(hex)
	if (hex== nil) then
		return 255,255,255,255;
	end
    hex = hex:gsub("#","")
    return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6)), tonumber("0x"..hex:sub(7,8))
end

-- expected to extract A R G B from a hex color 0xFFFFFFFF
function sprites:SetColor(newColor)
	local a,r,g,b = hex2argb(newColor);
	self.alpha = a or 255;
	self.color = {r or 255, g or 255, b or 255};
end

function sprites:ClearTexture()
	self.texture = nil;
	self.height = nil;
	self.width = nil;
end

function sprites:Render()

	if (self.visible and self.texture ~= nil and self.sprite ~= nil) then

		self.sprite:Begin();

		-- collect our information for rendering
		local color = d3d8.D3DCOLOR_ARGB(self.alpha, self.color[1], self.color[2], self.color[3]);
		self.rect.right = self.width;
		self.rect.bottom = self.height;
		self.vec_position.x = self.position_x;
		self.vec_position.y = self.position_y;
		self.vec_scale.x = self.scale_x;
		self.vec_scale.y = self.scale_y;
		self.sprite:Draw(self.texture, self.rect, self.vec_scale, nil, 0.0, self.vec_position, color);

		self.sprite:End();
	end

end

function sprites:new()
	local o = {};
    setmetatable(o, self);
    self.__index = self;

	-- setup our default values
	o.visible = true;
	o.repeat_x = 0;
	o.repeat_y = 0;
	o.scale_x = 1;
	o.scale_y = 1;
	o.position_x = 0;
	o.position_y = 0;
	o.height = 0;
	o.width = 0;
	o.color = 0xFFFFFFFF;
	o.alpha = 255;
	o.color = {255,255,255};
	o.texture = nil;
	o.rect = ffi.new('RECT', { 0, 0, 32, 32, });
	o.vec_position = ffi.new('D3DXVECTOR2', { 0, 0, });
	o.vec_scale = ffi.new('D3DXVECTOR2', { 1.0, 1.0, });
	o.sprite = nil;
	o.d3dEvent = 'sprites'..tostring(o);
	
	ashita.events.register('d3d_present', o.d3dEvent, self.Render:bind1(o));

    return o;
end

function sprites:destroy()
	print('fert');
	if (self.d3dEvent ~= nil) then
		ashita.events.unregister('d3d_present', self.d3dEvent);
	end
end

return sprites;