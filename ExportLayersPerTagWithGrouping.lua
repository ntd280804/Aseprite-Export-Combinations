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
local err = dofile("main.lua")
if err ~= 0 then return err end

local n_layers = 0

local function splitTagToFolder(tagname)
  local parts = {}
  for part in string.gmatch(tagname, "[^_]+") do
    table.insert(parts, part)
  end
  return table.concat(parts, "/")
end

local function exportLayers(sprite, root_layer, pathTemplate, group_sep, data, groupPrefix)
  for _, layer in ipairs(root_layer.layers) do
    if layer.isGroup then
      local prevVis = layer.isVisible
      layer.isVisible = true
      local newPrefix = groupPrefix .. layer.name .. group_sep
      exportLayers(sprite, layer, pathTemplate, group_sep, data, newPrefix)
      layer.isVisible = prevVis
    elseif root_layer ~= sprite then
      layer.isVisible = true

      local baseFolder = pathTemplate:gsub("{layergroups}", groupPrefix)
      os.execute('mkdir "' .. Dirname(baseFolder) .. '"')

      -- Luôn export dưới dạng spritesheet
      local sheettype = SpriteSheetType.HORIZONTAL
      if data.tagsplit == "To Rows" then
        sheettype = SpriteSheetType.ROWS
      elseif data.tagsplit == "To Columns" then
        sheettype = SpriteSheetType.COLUMNS
      end

      if #sprite.tags > 0 then
        for _, tag in ipairs(sprite.tags) do
          local tagPath = splitTagToFolder(tag.name) .. "/"
          local fullPath = baseFolder .. tagPath .. layer.name .. "." .. data.format
          os.execute('mkdir "' .. Dirname(fullPath) .. '"')
          app.command.ExportSpriteSheet{
            ui=false, askOverwrite=false,
            type=sheettype, columns=0, rows=0,
            width=0, height=0, bestFit=false,
            textureFilename=fullPath,
            dataFilename="", dataFormat=SpriteSheetDataFormat.JSON_HASH,
            borderPadding=0, shapePadding=0,
            innerPadding=0, extrude=false,
            openGenerated=false,
            listLayers=layer, listSlices=true,
            splitLayers=false, splitTags=false,
            layer="", tag=tag.name
          }
          n_layers = n_layers + 1
        end
      else
        local fullPath = baseFolder .. layer.name .. "." .. data.format
        app.command.ExportSpriteSheet{
          ui=false, askOverwrite=false,
          type=sheettype, columns=0, rows=0,
          width=0, height=0, bestFit=false,
          textureFilename=fullPath,
          dataFilename="", dataFormat=SpriteSheetDataFormat.JSON_HASH,
          borderPadding=0, shapePadding=0,
          innerPadding=0, extrude=false,
          openGenerated=false,
          listLayers=layer, listSlices=true,
          splitLayers=false, splitTags=false,
          layer="", tag=""
        }
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
-- Xóa toàn bộ phần File Name Format, Group Separator và nhất là checkbox spritesheet
dlg:combobox{
  id = 'format',
  label = 'Export Format:',
  option = 'png',
  options = {'png', 'gif', 'jpg'}
}
dlg:slider{id = 'scale', label = 'Export Scale:', min = 1, max = 10, value = 1}
dlg:combobox{
  id = "tagsplit",
  label = "Split Tags:",
  option = 'To Rows',
  options = {'To Rows', 'To Columns'}
}
dlg:check{id = "save", label = "Save sprite:", selected = false}
dlg:button{id = "ok", text = "Export"}
dlg:button{id = "cancel", text = "Cancel"}

dlg:show()

if not dlg.data.ok then return 0 end

local output_path = Dirname(dlg.data.directory)
if not output_path then
  MsgDialog("Error", "No output directory specified."):show()
  return 1
end

-- Thiết lập cố định dữ liệu xuất
dlg.data.spritesheet = true
local group_sep = "/"
local pathTemplate = output_path .. "/" .. "{layergroups}/"

Sprite:resize(Sprite.width * dlg.data.scale, Sprite.height * dlg.data.scale)
local layers_visibility_data = HideLayers(Sprite)
exportLayers(Sprite, Sprite, pathTemplate, group_sep, dlg.data, "")
RestoreLayersVisibility(Sprite, layers_visibility_data)
Sprite:resize(Sprite.width / dlg.data.scale, Sprite.height / dlg.data.scale)

if dlg.data.save then
  Sprite:saveAs(dlg.data.directory)
end

MsgDialog("Success!", "Exported " .. n_layers .. " layers."):show()
return 0
