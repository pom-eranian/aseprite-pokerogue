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
local function draw_section(src_img, dest_img, src_rect, dest_rect, palette)
    local frame = src_rect
    local source = dest_rect
    for y = 0, frame.h - 1, 1 do
        for x = 0, frame.w - 1, 1 do
            local src_x = frame.x + x
            local src_y = frame.y + y
            local color_or_index = src_img:getPixel(src_x, src_y)
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
            -- DEPENDS ON THE COLOR MODE, MAKE SURE ITS NOT INDEXED, if indexed, grab the index coolor from the pallete, otherwise it is the color
            local dest_x = source.x + x
            local dest_y = source.y + y
            dest_img:drawPixel(dest_x, dest_y, color)
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


local function build(filepath)
    local f = io.open(filepath, "r+"):read('a')
    local jsondata = json.decode(f)
    local is_txtpacker = false

    if jsondata == nil then
        print("could not load file " .. filepath)
        print("check your json file for errors")

        return 1
    end

    -- catching our texturepacker format before default check
    if jsondata.textures ~= nil then
        jsondata = sort_json_table(jsondata)
        is_txtpacker = true

    elseif type(jsondata.frames) ~= "nil" then
        if not is_array(jsondata.frames) then
            -- convert it so we can use it as an array
            jsondata.frames = jhash_to_jarray(jsondata.frames)
        end
    else
        for k, v in pairs(jsondata) do
            print(k, type(k))
            print(v)
        end
        return
    end

    local image = app.image
    local sprite = app.sprite

    local og_size = jsondata.frames[1].sourceSize
    local new_sprite = Sprite(og_size.w, og_size.h)
    new_sprite.filename = app.fs.fileTitle(filepath);
    new_sprite:setPalette(sprite.palettes[1])

    local frame = new_sprite.frames[1]

    local sep = app.fs.pathSeparator -- for multiplatform compatibility

    local cel_palette = Palette(34)
    cel_palette:setColor(0, Color{ r=153, g=30, b=20, a=255 })
    cel_palette:setColor(1, Color{ r=252, g=75, b=17, a=255 })
    cel_palette:setColor(2, Color{ r=251, g=140, b=26, a=255 })
    cel_palette:setColor(3, Color{ r=248, g=179, b=48, a=255 })
    cel_palette:setColor(4, Color{ r=248, g=233, b=48, a=255 })
    cel_palette:setColor(5, Color{ r=176, g=243, b=40, a=255 })
    cel_palette:setColor(6, Color{ r=67, g=201, b=105, a=255 })
    cel_palette:setColor(7, Color{ r=48, g=213, b=200, a=255 })
    cel_palette:setColor(8, Color{ r=23, g=177, b=243, a=255 })
    cel_palette:setColor(9, Color{ r=3, g=122, b=255, a=255 })
    cel_palette:setColor(10, Color{ r=11, g=32, b=222, a=255 })
    cel_palette:setColor(11, Color{ r=15, g=1, b=196, a=255 })
    cel_palette:setColor(12, Color{ r=80, g=27, b=240, a=255 })
    cel_palette:setColor(13, Color{ r=79, g=0, b=165, a=255 })
    cel_palette:setColor(14, Color{ r=166, g=1, b=147, a=255 })
    cel_palette:setColor(15, Color{ r=254, g=74, b=211, a=255 })
    cel_palette:setColor(16, Color{ r=250, g=182, b=232, a=255 })
    cel_palette:setColor(17, Color{ r=89, g=19, b=12, a=255 })
    cel_palette:setColor(18, Color{ r=122, g=48, b=23, a=255 })
    cel_palette:setColor(19, Color{ r=140, g=77, b=14, a=255 })
    cel_palette:setColor(20, Color{ r=140, g=100, b=27, a=255 })
    cel_palette:setColor(21, Color{ r=158, g=147, b=30, a=255 })
    cel_palette:setColor(22, Color{ r=110, g=153, b=24, a=255 })
    cel_palette:setColor(23, Color{ r=19, g=145, b=55, a=255 })
    cel_palette:setColor(24, Color{ r=31, g=135, b=126, a=255 })
    cel_palette:setColor(25, Color{ r=11, g=93, b=128, a=255 })
    cel_palette:setColor(26, Color{ r=0, g=17, b=148, a=255 })
    cel_palette:setColor(27, Color{ r=11, g=11, b=143, a=255 })
    cel_palette:setColor(28, Color{ r=8, g=1, b=110, a=255 })
    cel_palette:setColor(29, Color{ r=42, g=14, b=125, a=255 })
    cel_palette:setColor(30, Color{ r=52, g=0, b=107, a=255 })
    cel_palette:setColor(31, Color{ r=92, g=0, b=80, a=255 })
    cel_palette:setColor(32, Color{ r=133, g=38, b=111, a=255 })
    cel_palette:setColor(33, Color{ r=133, g=97, b=123, a=255 })

    local unique_index = 0
    local duplicate_index = 0
    local duplicate_table = {}

    for index, aframe in pairs(jsondata.frames) do
        local src_loc = aframe.frame
        local place_loc = aframe.spriteSourceSize
        local dest_cel = new_sprite.cels[index]
        local dest_img = dest_cel.image

        -- hash is the topleftmost pixel of each sprite, assumes no partial spriteage
        local frame_src_hash = aframe.frame['x'] .. ',' .. aframe.frame['y']
        local frame_data = ": { x: " .. aframe.frame['x'] .. ", y: " .. aframe.frame['y'] .. ", w: " .. aframe.frame['w'] .. ", h: " .. aframe.frame['h'] .. ' }'

        if is_txtpacker then
            frame = new_sprite:newFrame(index)
        else
            frame = new_sprite:newFrame()
        end

        if duplicate_table[frame_src_hash] == nil then -- first encounter
            dest_cel.data = unique_index .. frame_data
            unique_index = unique_index + 1 -- new unique frame encountered
            duplicate_table[frame_src_hash] = {0, index} -- store index
        elseif type(duplicate_table[frame_src_hash]) == "table" then -- second
            dest_cel.data = new_sprite.cels[duplicate_table[frame_src_hash][2]].data -- pull from initial
            new_sprite.cels[duplicate_table[frame_src_hash][2]].color = cel_palette:getColor(duplicate_index % 34) -- colour first encounter
            duplicate_table[frame_src_hash] = duplicate_index -- overwrite table with palette index
            dest_cel.color = cel_palette:getColor(duplicate_index % 34) -- colour second/current encounter
            duplicate_index = duplicate_index + 1
        else
            dest_cel.data = duplicate_table[frame_src_hash] .. frame_data
            dest_cel.color = cel_palette:getColor(duplicate_table[frame_src_hash] % 34)
        end

        draw_section(image, dest_img, src_loc, place_loc, sprite.palettes[1])
        if aframe.duration ~= nil then
            frame.previous.duration = aframe.duration / 1000
        end
    end
    -- # is the length operator, delete the extra empty frame
    new_sprite:deleteFrame(#new_sprite.frames)

    -- IMPORTING FRAME TAGS
    if jsondata.meta ~= nil and jsondata.meta.frameTags then
        for index, tag_data in pairs(jsondata.meta.frameTags) do
            local name = tag_data.name
            local from = tag_data.from + 1
            local to = tag_data.to + 1
            local direction = tag_data.direction

            -- seems like exporting tags does not export their colors so no way to import them until aseprite starts exporting color of a tag in the output json file

            local new_tag = new_sprite:newTag(from, to)
            new_tag.name = name
            new_tag.aniDir = direction

        end
    end

    for index, frame_data in pairs(jsondata.frames) do
        if frame_data.duration then
            local duration = frame_data.duration

            local current_frame = app.activeFrame
            current_frame.duration = duration / 1000 -- duraction in the editor is in seconds, e.g 0.1
            app.command.GoToNextFrame()
        end
    end

    -- FIXES CEL BOUNDS FROM BEING INCORRECT https://github.com/aseprite/aseprite/issues/3206
    app.command.CanvasSize {
        ui = false,
        left = 0,
        top = 0,
        right = 0,
        bottom = 0,
        trimOutside = true
    }
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
    local sprite = app.activeSprite

    if sprite == nil then
        print("you are not viewing a sprite on the active tab")
        return 1
    end

    -- tries to guess that the png & json are in the same directory
    local json_filepath = app.fs.filePathAndTitle(sprite.filename) .. ".json"
    local exists_in_same_dir = app.fs.isFile(json_filepath)
    if exists_in_same_dir == false then
        json_filepath = "" -- not in same dir, look for it yourself
    end

    dlg:file{
        id = PICKER,
        label = "select animation data file(json)",
        title = "animimation tag importer",
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
