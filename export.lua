--[[
    Export Layer × Tag Combinations from Aseprite
    Author: Nguyễn Trần Dinh
    Based on original script by Gaspi (https://github.com/PKGaspi/AsepriteScripts)

    Description:
    This script exports combinations of layers and tags from Aseprite,
    with full support for nested layer groups.

    Designed for modular character systems in game engines like Unity,
    it enables easy customization of effects, skins, weapons, and body parts
    (head, torso, hands, legs).

    It also generates a meta.json file that maps each exported image
    to a key for easy lookup in Unity or other engines.
]]

local err = dofile("main.lua")
if err ~= 0 then return err end

local n_layers = 0
local meta_entries = {}

-- Splits a tag name like "Idle_Bow_Bare" into:
-- { folderPath = "Idle/Bow/Bare/", joinedTag = "Idle_Bow_Bare" }
local function splitTagToFolder(tagname)
  local parts = {}
  for part in string.gmatch(tagname, "[^_]+") do
    table.insert(parts, part)
  end
  return {
    folderPath = table.concat(parts, "/") .. "/", -- folder structure
    joinedTag = table.concat(parts, "_")          -- key format
  }
end

-- Recursive layer exporter
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

      local sheettype = SpriteSheetType.HORIZONTAL
      if data.tagsplit == "To Rows" then
        sheettype = SpriteSheetType.ROWS
      elseif data.tagsplit == "To Columns" then
        sheettype = SpriteSheetType.COLUMNS
      end

      if #sprite.tags > 0 then
        for _, tag in ipairs(sprite.tags) do
          local tagInfo = splitTagToFolder(tag.name)
          local fullFolder = baseFolder .. tagInfo.folderPath
          local filename = layer.name .. "." .. data.format
          local fullPath = fullFolder .. filename

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

          local meta_key = (groupPrefix .. tagInfo.joinedTag .. "_" .. layer.name):gsub("[/\\]", "_")
          fullPath = fullPath:gsub("[/\\]+", "/")

          table.insert(meta_entries, {
  key = meta_key,
  path = fullPath,
  frames = tag.toFrame.frameNumber - tag.fromFrame.frameNumber + 1
})

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

        local meta_key = (groupPrefix .. layer.name):gsub("[/\\]", "_")
        fullPath = fullPath:gsub("[/\\]+", "/")

        table.insert(meta_entries, {
          key = meta_key,
          path = fullPath,
          frames = #sprite.frames
        })
      end

      layer.isVisible = false
    end
  end
end

-- UI Dialog
local dlg = Dialog("Export layers")
dlg:file{
  id = "directory",
  label = "Output directory:",
  filename = Sprite.filename,
  open = false
}
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

-- Prepare export
local output_path = Dirname(dlg.data.directory)
if not output_path then
  MsgDialog("Error", "No output directory specified."):show()
  return 1
end

dlg.data.spritesheet = true
local group_sep = "/"
local pathTemplate = output_path .. "/" .. "{layergroups}/"

-- Perform actual export
Sprite:resize(Sprite.width * dlg.data.scale, Sprite.height * dlg.data.scale)
local layers_visibility_data = HideLayers(Sprite)
exportLayers(Sprite, Sprite, pathTemplate, group_sep, dlg.data, "")
RestoreLayersVisibility(Sprite, layers_visibility_data)
Sprite:resize(Sprite.width / dlg.data.scale, Sprite.height / dlg.data.scale)

if dlg.data.save then
  Sprite:saveAs(dlg.data.directory)
end

-- Export meta.json with frame count
local metafile = io.open(output_path .. "/meta.json", "w")
metafile:write('{\n  "entries": [\n')

for i, entry in ipairs(meta_entries) do
  local path = entry.path:gsub("\\", "/")
  local relative_path = path:match(".*(Assets/.*)") or path

  metafile:write(string.format(
    '    {\n      "path": "%s",\n      "key": "%s",\n      "frames": %d\n    }%s\n',
    relative_path, entry.key, entry.frames,
    i < #meta_entries and "," or ""
  ))
end

metafile:write("  ]\n}\n")
metafile:close()

-- Success dialog
MsgDialog("Success!", "Exported " .. n_layers .. " layers. Metadata saved to meta.json"):show()
return 0
