--[[
    cg_open_pokemon
    Developed for PokeRogue's folder hierarchy for sprites, as of August 2024.
    This script uses the established standard to automatically discover what sprites exist for a given formSpriteKey.
    Each row of checkboxes in the dialog controls one potential factor, such that checking both doubles the number of sprites opened at once.
    In any row, checking neither will cause no sprites to open at all.

    Attempts to use the Title of the current active Sprite when possible for convenience, though it has full Dialog:file capabilities.


  Credits:
    script by chaosgrimmon

    Public domain, do whatever you want

]]

local SEP = app.fs.pathSeparator

local SOURCE = "source"
local FRONT = "front"
local BACK = "back"
local STATIC = "static"
local EXP = "exp"
local NON_SHINY = "non-shiny"
local SHINY = "shiny"
local MALE = "male"
local FEMALE = "female"

-- enforces folder ordering through implicit table enumeration
local dirs = { EXP, BACK, SHINY, FEMALE }

local function recurse(data, root, key, depth)
    if data[depth] == nil then  -- leaf node, perform exit behaviour
        Sprite{ fromFile = root .. SEP .. key }
        return
    end
    -- assumes files of the left option never introduce a named subfolder
    if data[depth][1] then
        recurse(data, root, key, depth+1)
    end
    if data[depth][2] then
        recurse(data, root .. SEP .. dirs[depth], key, depth+1)
    end
end

local function build(data)
    local form_sprite_key = app.fs.fileTitle(data[SOURCE]) .. ".png"
    -- trims everything after "pokemon", leaving only the universal root folder
    local root = data[SOURCE]:gsub("pokemon.*", "pokemon")

    -- mandatory to ensure the data stays in order, unfortunately
    local prefs = { { data[STATIC], data[EXP] },
                    { data[FRONT], data[BACK] },
                    { data[NON_SHINY], data[SHINY] },
                    { data[MALE], data[FEMALE] }
                  }

    recurse(prefs, root, form_sprite_key, 1)
end

local dlg = Dialog("Open PokeRogue Spritesheets")

local filepath = app.sprite
if filepath == nil then  -- no active Sprite
   filepath = ""
else
   filepath = filepath.filename
end

-- "exp" in current filepath or exp counterpart located
local exp_flag = filepath:find("exp") ~= nil
                 or app.fs.isFile(filepath:gsub("pokemon", "pokemon" .. SEP .. "exp"))
                 or (filepath:find("variant") ~= nil and app.fs.isFile(filepath:gsub("variant", "variant" .. SEP .. "exp")))
local gender_flag = app.fs.isFile(filepath:gsub(SEP .. "(%d)", SEP .. "female" .. SEP .. "%1"))
                    or filepath:find(SEP .. "female") ~= nil

dlg:file{
        id = SOURCE,
        label = "select an asset",
        title = "open pokemon",
        filename = app.fs.filePathAndTitle(filepath),
        focus = app.sprite == nil,
        onchange = function()
            if app.fs.filePathAndTitle(filepath) ~= dlg.data[SOURCE] then
                filepath = dlg.data[SOURCE]
            end
            exp_flag = filepath:find("exp") ~= nil
                       or app.fs.isFile(filepath:gsub("pokemon", "pokemon" .. SEP .. "exp"))
                       or (filepath:find("variant") ~= nil and app.fs.isFile(filepath:gsub("variant", "variant" .. SEP .. "exp")))
            gender_flag = app.fs.isFile(filepath:gsub(SEP .. "(%d)", SEP .. "female" .. SEP .. "%1"))
                          or filepath:find(SEP .. "female") ~= nil
            dlg:modify{
                    id = STATIC,
                    visible = exp_flag
                }:modify{
                    id = EXP,
                    selected = exp_flag,  -- default to opening only if it exists
                    visible = exp_flag
                }:modify{
                    id = MALE,
                    visible = gender_flag
                }:modify{
                    id = FEMALE,
                    selected = gender_flag,  -- default to opening only if it exists
                    visible = gender_flag
                }:modify{
                    id = SOURCE,
                    filename = app.fs.filePathAndTitle(dlg.data[SOURCE])
                }
        end
    }:separator{
    }:check{
        id = FRONT,
        label = "sprite direction",
        selected = true,
        text = "front     "  -- needed for spacing
    }:check{
        id = BACK,
        selected = true,
        text = "back "
    }:check{
        id = STATIC,
        label = "sprite animation",
        selected = true,
        visible = exp_flag,
        text = "consistent"
    }:check{
        id = EXP,
        selected = exp_flag,
        visible = exp_flag,
        text = "exp   "
    }:check{
        id = NON_SHINY,
        label = "shiny sprite",
        selected = true,
        text = "non-shiny"
    }:check{
        id = SHINY,
        selected = false,  -- default to not opening the base shiny
        text = "shiny "
    }:check{
        id = MALE,
        label = "sprite gender",
        selected = true,
        visible = gender_flag,
        text = "male     "
    }:check{
        id = FEMALE,
        visible = gender_flag,
        selected = gender_flag,
        text = "female"
    }:button{
        id = "Ok",
        text = "Ok",
        focus = app.sprite ~= nil, -- does not focus if source is empty
        onclick = function()
            build(dlg.data)
            dlg:close()
        end
    }:show()
