local json = dofile('json.lua')

--[[
    jest_import_packed_atlas
    Useful in case you lose your ASE file and only have the output .png & .json files
    This script IMPORTS packed sprites, e,g texture atlases, or exports from aseprite, back into their original form.
    Just open the png file up as the current tab, select the corresponding json and done.
    !!WARNING: PROBABLY DOES NOT SUPPORT ROTATED TEXTURE ATLASES!!
    It will also import tags if they exist in the json file

    This script also has CLI support so you can mass convert your texture atlases:
    NOTE THAT PATHS MUST BE ABSOLUTE, EG:
    WARNING! IT WILL SAVE IN THE SAME DIRECTORY AS THE PNG FILE! Becareful if you already have an .ase file in the same directory with the same name as the .png
    '--save-as' flag DOES NOT WORK and I'm too lazy to add an export script-param var
    png & json paths don't have to be absolute but script path has to, at least these are my problems. Use all absolute paths if you are having issues
    aseprite.exe <C:\SPRITE.png> --script-param json="C:\SPRITE.json" --script "C:\jest_import_packed_atlas.lua" --batch

    Your .json file can be either in array form, e.g:

{"frames": [
    {
        "filename": "Green Flash"
        "frame": {"x":1,"y":1,"w":31,"h":301},
        "rotated": false,
        "trimmed": false,
        "spriteSourceSize": {"x":0,"y":0,"w":31,"h":301},
        "sourceSize": {"w":31,"h":301
    }
]}

or hash form:

{"frames": {
    "Green Flash":
    {
        "frame": {"x":1,"y":1,"w":31,"h":301},
        "rotated": false,
        "trimmed": false,
        "spriteSourceSize": {"x":0,"y":0,"w":31,"h":301},
        "sourceSize": {"w":31,"h":301}
}}}

    If you see all white colors, it means you didn't have the packed sprite selected as the current tab when running this script

    Check out jest_import_existing_tags(https://github.com/jestarray/aseprite-scripts/blob/master/jest_import_existing_tags.lua) if your json file also has meta data animation tags
  Credits:
    json decoding by rxi - https://github.com/rxi/json.lua

    script by jest(https://github.com/jestarray/aseprite-scripts) - for aseprite versions > 1.2.10

    Public domain, do whatever you want
]]

-- start main

local function split(str, sep)
    local result = {}
    local regex = ("([^%s]+)"):format(sep)
    for each in str:gmatch(regex) do table.insert(result, each) end
    return result
end

-- Image, Image, Rect, Rect, palette
-- src and dest are image classes
local function draw_section(src_img, dest_img, src_rect, palette)
    local frame = src_rect
    for y = 0, frame.h - 1, 1 do
        for x = 0, frame.w - 1, 1 do
            local color_or_index = src_img:getPixel(x, y)
            local color;
            if src_img.colorMode == ColorMode.INDEXED then
                -- fixes greenish artifacts when importing from an indexed file: https://discord.com/channels/324979738533822464/324979738533822464/975147445564604416
                -- because indexed sprites have a special index as the transparent color: https://www.aseprite.org/docs/color-mode/#indexed
                if color_or_index ~= src_img.spec.transparentColor then
                    color = palette:getColor(color_or_index)
                else
                    color = Color {r = 0, g = 0, b = 0, a = 0}
                end
            else
                color = color_or_index
            end
            -- DEPENDS ON THE COLOR MODE, MAKE SURE ITS NOT INDEXED, if indexed, grab the index color from the palette, otherwise it is the color
            dest_img:drawPixel(x, y, color)
        end
    end
end

-- takes in jsondata.frames
local function jhash_to_jarray(hash)
    local res = {}
    for key, obj in pairs(hash) do
        obj["filename"] = key
        table.insert(res, obj)
    end
    table.sort(res, function(a, b) return a.filename < b.filename end)
    return res
end

local function is_array(hash)
    local res = false
    for key, obj in pairs(hash) do
        if type(key) == "number" then
            res = true
            break
        end
    end
    return res
end

-- adapted from jhash_to_jarray()
local function sort_by_framename(hash)
    local sorted_frames = {}

    for i, frame in ipairs(hash) do
        table.insert(sorted_frames, frame)
    end

    table.sort(sorted_frames, function(a, b)
        return a.filename < b.filename
    end)

    return sorted_frames
end

local function sort_json_table(table)
    local res = {}

    res.frames = table.textures[1].frames
    res.meta = table.meta
    res.meta.app = ""
    res.meta.version = ""
    res.meta.image = table.textures[1].image
    res.meta.format = table.textures[1].format
    -- res.meta.size = table.textures[1].size
    res.meta.scale = table.textures[1].scale
    res.frames = sort_by_framename(res.frames)
    return res
end

local function hex_to_color(s)
    return Color{ r=tonumber(s:sub(1,2), 16), g=tonumber(s:sub(3,4), 16), b=tonumber(s:sub(5,6), 16), a=255 }
end

local hexadec = {'0', '1', '2', '3', '4', '5' , '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'}
local function tohex(n)
    return hexadec[(n // 16) + 1] .. hexadec[(n % 16) + 1]
end

local function color_to_hex(c)
    return tohex(c.red) .. tohex(c.green) .. tohex(c.blue)
end

local function apply_variant_palette(sprite, image, filepath, palette_table)
    local new_sprite = Sprite(sprite.width, sprite.height)
    new_sprite.filename = app.fs.fileTitle(filepath)
    new_sprite:setPalette(sprite.palettes[1])

    for i=0,#new_sprite.palettes[1]-1 do
        local source_color = color_to_hex(sprite.palettes[1]:getColor(i))
        for k, v in pairs(palette_table) do
            if source_color == k then
                new_sprite.palettes[1]:setColor(i, hex_to_color(v))
                break
            end
        end
    end

    draw_section(image, new_sprite.cels[1].image, {w=sprite.width, h=sprite.height}, new_sprite.palettes[1])
end

local function build(filepath)
    local f = io.open(filepath, "r+"):read('a')
    local jsondata = json.decode(f)

    if jsondata == nil then
        print("could not load file " .. filepath)
        print("check your json file for errors")

        return 1
    end

    local sprite = app.sprite
    local image = app.image

    for k, v in pairs(jsondata) do
        if k ~= 3 then
            apply_variant_palette(sprite, image, app.fs.fileTitle(string.sub(filepath, 1, -6) .. "_" .. k), v)
        end
    end
end

local JKEY = "json"
local from_cli_json_path = app.params[JKEY]

if from_cli_json_path ~= nil then
    build(from_cli_json_path)

    -- weirdly filename must also have extension despite specifing it in 'filename-format' below
    local name = app.fs.filePathAndTitle(from_cli_json_path) .. ".ase"
    app.command.saveFileAs {["filename"] = name, ["filename-format"] = ".ase"}
else
    local dlg = Dialog()

    local PICKER = "picker"
    local sprite = app.sprite

    if sprite == nil then
        print("you are not viewing a sprite on the active tab")
        return 1
    end

    -- tries to guess that the png & json are in the same directory
    local json_filepath = app.fs.filePathAndTitle(sprite.filename)
    json_filepath = string.gsub(json_filepath, "pokemon", "pokemon" .. app.fs.pathSeparator .. "variant")  .. ".json"

    local exists_in_same_dir = app.fs.isFile(json_filepath)
    if exists_in_same_dir == false then
        json_filepath = "" -- not in same dir, look for it yourself
    end

    dlg:file{
        id = PICKER,
        label = "select variant palette file (json)",
        title = "variant palette importer",
        load = true,
        open = true,
        filename = json_filepath,
        filetypes = {"json"}
    }:button{
        id = "Ok",
        text = "Ok",
        focus = json_filepath ~= "", --defaults to first (file picker) if false
        onclick = function()
            build(dlg.data[PICKER])
            dlg:close()
        end
    }:show()
end
