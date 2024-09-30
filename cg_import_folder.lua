--[[
    cg_import_folder
    After selecting a file in a folder, opens every .png in that folder as a Cel of a single Sprite.
    The overall Sprite is given the name of the folder, and each Cel is given a Tag with the name of the file that the Cel was filled with.
    The height and width of every single Cel is set in the initial Dialog, and defaults to the 40x30 pixels that PokeRogue uses for Pokemon icon sprites.


  Credits:
    script by chaosgrimmon

    Public domain, do whatever you want
]]

local function build(source, width, height)
    -- source is not a directory, or app.fs.filePath broke somehow
    if not app.fs.isDirectory(source) then
        app.alert("Your file wasn't in a folder. Somehow. " .. source)
        return 1
    end

    local sprite = Sprite(width, height)
    sprite.filename = app.fs.fileName(source)
    sprite:setPalette(Palette(1))
    local c = 0  -- necessary for when non-pngs are in the same folder

    for i,filename in pairs(app.fs.listFiles(source)) do
        if app.fs.fileExtension(filename) == "png" then  -- hardcoded only .pngs
            c = c + 1
            local image = Image{ fromFile=app.fs.joinPath(source, filename) }
            if image.colorMode ~= ColorMode.RGB then
                -- for whatever reason, a separate Sprite IS mandatory to
                --   change the pixel format.
                -- since sprite is already in RGB, 'changing' its format means 
                --   nothing changes and the non-RGB Images are parsed incorrectly
                local temp_sprite = Sprite{ fromFile=app.fs.joinPath(source, filename) }
                app.command.ChangePixelFormat{ format="rgb" }
                image = Image(temp_sprite)
                temp_sprite:close()
            end
            local cel = sprite:newCel(app.layer, sprite:newEmptyFrame(c), image)
            local tag = sprite:newTag(c,c)
            tag.name = app.fs.fileTitle(filename)
        end
    end
    for i,tag in ipairs(sprite.tags) do  -- fix tag endpoints
        tag.toFrame = tag.fromFrame
    end
    -- delete tailing empty Frame from initial Sprite call
    sprite:deleteFrame(#sprite.frames)
end


local dlg = Dialog("Import Folder Contents")

local SOURCE = "source"
local HEIGHT = "height"
local WIDTH = "width"

local sprite = app.sprite
local filepath;
if sprite == nil then
    filepath = ""  -- no active sprite to default to, locate manually
else
    filepath = app.sprite.filename
end

dlg:file{
        id = SOURCE,
        -- yes, this is the best we can do.
        --   Aseprite does not have a Dialog element for selecting folders.
        label = "select a file in the folder",
        title = "select a file in the folder",
        load = false,
        open = false,
        filename = app.fs.filePath(filepath),
        focus = app.sprite == nil,  -- focus if source is empty
        filetypes = {},
        onchange = function ()
            if app.fs.isFile(dlg.data[SOURCE]) then  -- select folder instead
                local sprite = Sprite{ fromFile = dlg.data[SOURCE]}
                dlg:modify{
                    id = WIDTH,
                    text = sprite.width
                }:modify{
                    id = HEIGHT,
                    text = sprite.height
                }:modify{
                    id = SOURCE,
                    filename = app.fs.filePath(dlg.data[SOURCE])
                }
                sprite:close()
            end
        end
    }:number{
        id = WIDTH,
        -- both on same label to have both boxes on one line
        label = "largest width and height",
        text = "40",  -- default for PokeRogue Pokemon icons
        decimals = 0  -- no fractional pixels
    }:number{
        id = HEIGHT,
        text = "30",  -- default for PokeRogue Pokemon icons
        decimals = 0  -- no fractional pixels
    }:button{
        id = "Ok",
        text = "Ok",
        focus = app.sprite ~= nil, -- does not focus if source is empty
        onclick = function()
            build(dlg.data[SOURCE], dlg.data[WIDTH], dlg.data[HEIGHT])
            dlg:close()
        end
    }:show()
