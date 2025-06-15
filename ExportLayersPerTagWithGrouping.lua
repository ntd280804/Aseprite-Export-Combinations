--[[
    Export Layer × Tag Combinations from Aseprite
    Author: Nguyễn Trần Dinh
    Based on original script by Gaspi (https://github.com/PKGaspi/AsepriteScripts)

    Description:
    This script allows exporting combinations of layers and tags from Aseprite, 
    with full support for nested layer groups. Designed for modular character 
    systems in game engines like Unity, it enables easy customization of 
    effects, skins, weapons, and body parts (head, torso, hands, legs).

    Source and inspiration: https://github.com/PKGaspi/AsepriteScripts
]]
local err = dofile("main.lua") -- Chứa HideLayers, RestoreLayersVisibility, Dirname, ...
if err ~= 0 then return err end

local n_layers = 0

local function exportLayers(sprite, root_layer, pathTemplate, group_sep, data, groupPrefix)
    for _, layer in ipairs(root_layer.layers) do
        if layer.isGroup then
            local previousVisibility = layer.isVisible
            layer.isVisible = true
            local newGroupPrefix = groupPrefix .. layer.name .. group_sep
            exportLayers(sprite, layer, pathTemplate, group_sep, data, newGroupPrefix)
            layer.isVisible = previousVisibility
        elseif root_layer ~= sprite then
            layer.isVisible = true

            -- Gán các giá trị format
            local groupPath = groupPrefix -- Ví dụ: Head/
            local layername = layer.name -- Ví dụ: Bare
            local baseFolderPath = pathTemplate
                :gsub("{layergroups}", groupPath)
                :gsub("{layername}", layername .. "/")

            -- Tạo thư mục nếu chưa có
            os.execute('mkdir "' .. Dirname(baseFolderPath) .. '"')

            -- Loại spritesheet
            if data.spritesheet then
                local sheettype = SpriteSheetType.HORIZONTAL
                if data.tagsplit == "To Rows" then
                    sheettype = SpriteSheetType.ROWS
                elseif data.tagsplit == "To Columns" then
                    sheettype = SpriteSheetType.COLUMNS
                end

                -- Xuất theo tag
                if #sprite.tags > 0 then
                    for _, tag in ipairs(sprite.tags) do
                        local tagname = tag.name
                        local finalPath = baseFolderPath
                            :gsub("{tagname}", tagname)
                            :gsub("%." .. data.format .. "$", "") .. "." .. data.format

                        app.command.ExportSpriteSheet{
                            ui=false,
                            askOverwrite=false,
                            type=sheettype,
                            columns=0,
                            rows=0,
                            width=0,
                            height=0,
                            bestFit=false,
                            textureFilename=finalPath,
                            dataFilename="",
                            dataFormat=SpriteSheetDataFormat.JSON_HASH,
                            borderPadding=0,
                            shapePadding=0,
                            innerPadding=0,
                            extrude=false,
                            openGenerated=false,
                            layer="",
                            tag=tagname,
                            splitLayers=false,
                            splitTags=false,
                            listLayers=layer,
                            listTags=false,
                            listSlices=true,
                        }
                        n_layers = n_layers + 1
                    end
                else
                    -- Không có tag, xuất 1 file
                    local finalPath = baseFolderPath:gsub("{tagname}", "")
                    app.command.ExportSpriteSheet{
                        ui=false,
                        askOverwrite=false,
                        type=sheettype,
                        columns=0,
                        rows=0,
                        width=0,
                        height=0,
                        bestFit=false,
                        textureFilename=finalPath,
                        dataFilename="",
                        dataFormat=SpriteSheetDataFormat.JSON_HASH,
                        borderPadding=0,
                        shapePadding=0,
                        innerPadding=0,
                        extrude=false,
                        openGenerated=false,
                        layer="",
                        tag="",
                        splitLayers=false,
                        splitTags=false,
                        listLayers=layer,
                        listTags=false,
                        listSlices=true,
                    }
                    n_layers = n_layers + 1
                end
            else
                -- Xuất ảnh đơn
                local finalPath = baseFolderPath:gsub("{tagname}", "")
                sprite:saveCopyAs(finalPath)
                n_layers = n_layers + 1
            end

            layer.isVisible = false
        end
    end
end

-- UI
local dlg = Dialog("Export layers")
dlg:file{
    id = "directory",
    label = "Output directory:",
    filename = Sprite.filename,
    open = false
}
dlg:entry{
    id = "filename",
    label = "File name format:",
    text = "{layergroups}{layername}{tagname}"
}
dlg:combobox{
    id = 'format',
    label = 'Export Format:',
    option = 'png',
    options = {'png', 'gif', 'jpg'}
}
dlg:combobox{
    id = 'group_sep',
    label = 'Group separator:',
    option = '/',
    options = {'/'}
}
dlg:slider{id = 'scale', label = 'Export Scale:', min = 1, max = 10, value = 1}
dlg:check{
    id = "spritesheet",
    label = "Export as spritesheet:",
    selected = true
}
dlg:combobox{
    id = "tagsplit",
    label = "  Split Tags:",
    visible = true,
    option = 'To Rows',
    options = {'To Rows', 'To Columns'}
}
dlg:check{id = "save", label = "Save sprite:", selected = false}
dlg:button{id = "ok", text = "Export"}
dlg:button{id = "cancel", text = "Cancel"}
dlg:show()

if not dlg.data.ok then return 0 end

local output_path = Dirname(dlg.data.directory)
local filename = dlg.data.filename .. "." .. dlg.data.format

if output_path == nil then
    local dlg = MsgDialog("Error", "No output directory was specified.")
    dlg:show()
    return 1
end

local group_sep = dlg.data.group_sep
filename = filename
    :gsub("{spritename}", RemoveExtension(Basename(Sprite.filename)))
    :gsub("{groupseparator}", group_sep)

Sprite:resize(Sprite.width * dlg.data.scale, Sprite.height * dlg.data.scale)
local layers_visibility_data = HideLayers(Sprite)
exportLayers(Sprite, Sprite, output_path .. "/" .. filename, group_sep, dlg.data, "")
RestoreLayersVisibility(Sprite, layers_visibility_data)
Sprite:resize(Sprite.width / dlg.data.scale, Sprite.height / dlg.data.scale)

if dlg.data.save then
    Sprite:saveAs(dlg.data.directory)
end

local dlg = MsgDialog("Success!", "Exported " .. n_layers .. " layers.")
dlg:show()
return 0
