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
dofile("main.lua")  -- loads shared helpers like Sprite and MsgDialog

local spr = Sprite
if not spr then
  MsgDialog("Error", "No sprite is currently open!"):show()
  return 1
end

-- Count the number of tags
local count = #spr.tags

-- Show result
MsgDialog("Tag Count", "Total number of tags: " .. count):show()
return 0
