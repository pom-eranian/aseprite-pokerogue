--[[
    cg_sort_by_order
    Sorts the current palette using the first occurrence of each unique colour.
    Order is determined left-to-right, up-to-down. Unused colours are shuffled to the back.
    Does not add or remove palette entries, it only reorders existing indices.
    Preserves INDEXED and RGB colour modes.
    Does not preserve GRAY, which maintains a 256-index greyscale palette, and erases any other ordering.

  Credits:
    script by chaosgrimmon

    Public domain, do whatever you want
]]

local function sort_order()
    local sprite = app.sprite
    local image = app.image
    local counter = 0
    local sort_table = {}

    -- loads sort_table with the integer pixelColor keys
    for i = 0, #sprite.palettes[1]-1, 1 do
        sort_table[sprite.palettes[1]:getColor(i).rgbaPixel] = -1
    end

    for y = 0, sprite.height - 1, 1 do
        for x= 0, sprite.width - 1, 1 do
            local color = image:getPixel(x, y)

            if sort_table[color] == -1 then  -- first occurrence, replace placeholder -1
                sort_table[color] = counter
                counter = counter + 1
            end
        end
        if counter >= #sprite.palettes[1] then  -- all indices sorted
            break
        end
    end

    local palette = Palette(#sprite.palettes[1])
    for k,v in pairs(sort_table) do -- index, color
        if v == -1 then  -- not encountered
            palette:setColor(counter, k)
            counter = counter + 1
        else
            palette:setColor(v, k)
        end
    end

    app.sprite:setPalette(palette)
end

if app.sprite == nil then
    print("you are not viewing a sprite on the active tab")
    return 1
end

local color_mode = app.sprite.colorMode
app.command.ChangePixelFormat { format = "rgb" }

sort_order()

if color_mode == ColorMode.INDEXED then
    app.command.ChangePixelFormat { format = "indexed" }
end
