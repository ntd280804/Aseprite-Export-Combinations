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
-- Import main.
local err = dofile("main.lua")
if err ~= 0 then return err end

local n_layers = 0

local function exportLayers(sprite, root_layer, filename, group_sep, data)
    for _, layer in ipairs(root_layer.layers) do
        local filename = filename
        if layer.isGroup then
            local previousVisibility = layer.isVisible
            layer.isVisible = true
            filename = filename:gsub("{layergroups}", layer.name .. group_sep .. "{layergroups}")
            exportLayers(sprite, layer, filename, group_sep, data)
            layer.isVisible = previousVisibility
        else
            layer.isVisible = true
            filename = filename:gsub("{layergroups}", "")
            filename = filename:gsub("{layername}", layer.name)
            os.execute("mkdir \"" .. Dirname(filename) .. "\"")

            if data.spritesheet then
                local sheettype = SpriteSheetType.HORIZONTAL
                if (data.tagsplit == "To Rows") then
                    sheettype = SpriteSheetType.ROWS
                elseif (data.tagsplit == "To Columns") then
                    sheettype = SpriteSheetType.COLUMNS
                end

                if #sprite.tags > 0 then
                    for _, tag in ipairs(sprite.tags) do
                        local tag_filename = filename
                        tag_filename = tag_filename:gsub("{tagname}", tag.name)
                        tag_filename = tag_filename:gsub("%." .. data.format .. "$", "")
                        tag_filename = tag_filename .. "." .. data.format

                        app.command.ExportSpriteSheet{
                            ui=false,
                            askOverwrite=false,
                            type=sheettype,
                            columns=0,
                            rows=0,
                            width=0,
                            height=0,
                            bestFit=false,
                            textureFilename=tag_filename,
                            dataFilename="",
                            dataFormat=SpriteSheetDataFormat.JSON_HASH,
                            borderPadding=0,
                            shapePadding=0,
                            innerPadding=0,
                            extrude=false,
                            openGenerated=false,
                            layer="",
                            tag=tag.name,
                            splitLayers=false,
                            splitTags=false,
                            listLayers=layer,
                            listTags=false,
                            listSlices=true,
                        }

                        n_layers = n_layers + 1
                    end
                else
                    app.command.ExportSpriteSheet{
                        ui=false,
                        askOverwrite=false,
                        type=sheettype,
                        columns=0,
                        rows=0,
                        width=0,
                        height=0,
                        bestFit=false,
                        textureFilename=filename,
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
                sprite:saveCopyAs(filename)
                n_layers = n_layers + 1
            end

            layer.isVisible = false
        end
    end
end

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
    text = "{layergroups}{tagname}{layername}"
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
    options = {'-','/', '_'}
}
dlg:slider{id = 'scale', label = 'Export Scale:', min = 1, max = 10, value = 1}
dlg:check{
    id = "spritesheet",
    label = "Export as spritesheet:",
    selected = true,
	visible = false
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
filename = filename:gsub("{spritename}", RemoveExtension(Basename(Sprite.filename)))
filename = filename:gsub("{groupseparator}", group_sep)

Sprite:resize(Sprite.width * dlg.data.scale, Sprite.height * dlg.data.scale)
local layers_visibility_data = HideLayers(Sprite)
exportLayers(Sprite, Sprite, output_path .. filename, group_sep, dlg.data)
RestoreLayersVisibility(Sprite, layers_visibility_data)
Sprite:resize(Sprite.width / dlg.data.scale, Sprite.height / dlg.data.scale)

if dlg.data.save then Sprite:saveAs(dlg.data.directory) end

local dlg = MsgDialog("Success!", "Exported " .. n_layers .. " layers.")
dlg:show()

return 0
