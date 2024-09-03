local json = dofile('json.lua')

--[[
    cg_apply_variant_palette
    This script is designed for PokeRogue's variant palette engine.
    https://github.com/pagefaultgames/pokerogue
    It takes a non-shiny Pokemon's spritesheet, stored in the same file directory as it is on the above  repository, and opens that Pokemon's variant spritesheets.
    When those variants are stored as images, it opens them directly, and when they are stored as palette maps, it applies that map to a copy of the original sheet.

    Just open the png file up as the current tab, select the corresponding json and done.
    !!WARNING: PROBABLY DOES NOT SUPPORT ROTATED TEXTURE ATLASES!!

    I'm not jest, so the following probably isn't true. It might though!

    This script might also have CLI support so you can mass convert your texture atlases:
    NOTE THAT PATHS MUST BE ABSOLUTE, EG:
    WARNING! IT WILL SAVE IN THE SAME DIRECTORY AS THE PNG FILE! Be careful if you already have an .ase file in the same directory with the same name as the .png
    '--save-as' flag DOES NOT WORK and I'm too lazy to add an export script-param var
    png & json paths don't have to be absolute but script path has to, at least these are my problems. Use all absolute paths if you are having issues
    aseprite.exe <C:\SPRITE.png> --script-param json="C:\SPRITE.json" --script "C:\jest_import_packed_atlas.lua" --batch

    A palette map .json file should probably look something like this:
{
	"1": {
		"983a29": "6231a5",
		"f07944": "ab6ce0",
		"101010": "101010",
		"bf5633": "6231a5",
		"987028": "061530",
		"f7e77a": "b55390",
		"e8b848": "872b59",
		"56301f": "471b70",
		"af7045": "6231a5",
		"8d452e": "c5b3ca",
		"969696": "262424",
		"414141": "404040",
		"f8f8f8": "f7e4fc",
		"d8d8c8": "c093c3",
		"5c5c5c": "262424",
		"000000": "101010"
	}
}

    Check out jest_import_existing_tags(https://github.com/jestarray/aseprite-scripts/blob/master/jest_import_existing_tags.lua) if your json file also has meta data animation tags

  Credits:
    json decoding by rxi - https://github.com/rxi/json.lua

    components and UI by jest(https://github.com/jestarray/aseprite-scripts) - for aseprite versions > 1.2.10

    color functions by Kacper Woźniak - https://thkaspar.itch.io/theme-preferences

    adapted from jest's jest_import_packed_atlas.lua by chaosgrimmon for PokeRogue

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
            -- fixes greenish artifacts when importing from an indexed file: https://discord.com/channels/324979738533822464/324979738533822464/975147445564604416
            -- because indexed sprites have a special index as the transparent color: https://www.aseprite.org/docs/color-mode/#indexed
            -- since it's indexed, grab the index color from the palette
            if color_or_index ~= src_img.spec.transparentColor then
                color = palette:getColor(color_or_index)
            else
                color = Color {r = 0, g = 0, b = 0, a = 0}
            end
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

local function color_to_hex(c)
    return string.format("%02x%02x%02x", c.red, c.green, c.blue)
end

local function apply_variant_palette(sprite, image, filepath, palette_table)
    local new_sprite = Sprite(sprite.width, sprite.height)
    new_sprite.filename = filepath
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

local function build(filepath, sprite, image)
    local f = io.open(filepath, "r+"):read('a')
    local jsondata = json.decode(f)

    if jsondata == nil then
        print("could not load file " .. filepath)
        print("check your json file for errors")

        return 1
    end

    for k, v in pairs(jsondata) do
        apply_variant_palette(sprite, image, filepath:sub(1, -6) .. "_" .. (k + 1) .. ".png", v)
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
    local dlg = Dialog("Open Variants")

    local PICKER = "picker"

    -- colour replacement only works on INDEXED Sprites
    if app.sprite.colorMode ~= ColorMode.INDEXED then
        app.command.ChangePixelFormat { format = "indexed" }
    end -- needs to be before app.sprite/image caching
    local sprite = app.sprite
    local image = app.image

    if sprite == nil then
        print("you are not viewing a sprite on the active tab")
        return 1
    end

    local json_filepath = app.fs.filePathAndTitle(sprite.filename)
    json_filepath = json_filepath:gsub("pokemon", "pokemon" .. app.fs.pathSeparator .. "variant") .. ".json"

    -- if any variant sprites exist in the expected location, they are immediately opened
    for i=1,3 do
        local var_sprite_filepath = json_filepath:sub(1,-6) .. "_" .. i .. ".png"
        if app.fs.isFile(var_sprite_filepath) then
            app.open(var_sprite_filepath)
        end
    end

    if app.fs.isFile(json_filepath) == false then  -- search in variant folder counterpart
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
            build(dlg.data[PICKER], sprite, image)
            dlg:close()
        end
    }:show()
end
