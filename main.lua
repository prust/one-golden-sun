local anim8 = require('anim8')
local sti = require('sti')
local gamera = require('gamera')
local _ = require('underscore')
require('game')
--require('mobdebug').start()

local ver = '0.0.1'
local width, height
local camera
local map
local auto_scroll_region = 0.12 -- 12% of the width/height on all sides of window
local auto_scroll_speed = 500
local tilesets = {}
local tilesetsByName = {}
local types = {'Road'}

function love.load()
  love.graphics.setDefaultFilter( 'nearest', 'nearest' )
  love.window.setTitle('One Golden Sun ' .. ver)
  width, height = love.graphics.getDimensions()
  love.window.setMode(width, height, {resizable=true, vsync=false, minwidth=400, minheight=300})
  camera = gamera.new(0, 0, 2000, 2000) -- TODO: pull this from the map?
  camera:setScale(2.0)

  music = love.audio.newSource("assets/intro.mp3")
  music:play()
  
  map = sti("world2.lua", {"bump"})
  for i, tileset in ipairs(map.tilesets) do
    local name = tileset.image_filename:gsub('assets/', ''):gsub('.png', '')
    local tileset_info = {
      type = name:find('Road') and 'Road' or nil,
      tiles = {}
    }
    tilesets[i] = tileset_info
    tilesetsByName[name] = tileset_info
  end
  for i, tile in ipairs(map.tiles) do
    tilesets[tile.tileset].tiles[tile.id] = tile
  end
end

function love.update(dt)
  map:update(dt)
  mouse_x, mouse_y = love.mouse.getPosition()

  -- auto-scroll if mouse is near window edges (and still in the window)
  if mouse_x > 0 and mouse_x < width and mouse_y > 0 and mouse_y < width then
    local a_s_region_horiz = width * auto_scroll_region
    local a_s_region_vert = height * auto_scroll_region
    local cam_x, cam_y = camera:getPosition()
    
    local cam_x_pct = 0
    if mouse_x < a_s_region_horiz then
      cam_x_pct = -(a_s_region_horiz - mouse_x) / a_s_region_horiz
    elseif mouse_x > width - a_s_region_horiz then
      cam_x_pct = (mouse_x - (width - a_s_region_horiz)) / a_s_region_horiz
    end
    cam_x = cam_x + cam_x_pct * auto_scroll_speed * dt

    local cam_y_pct = 0
    if mouse_y < a_s_region_vert then
      cam_y_pct = -(a_s_region_vert - mouse_y) / a_s_region_vert
    elseif mouse_y > height - a_s_region_vert then
      cam_y_pct = (mouse_y - (height - a_s_region_vert)) / a_s_region_vert
    end
    cam_y = cam_y + cam_y_pct * auto_scroll_speed * dt
    
    camera:setPosition(cam_x, cam_y)
  end
end

function love.mousereleased(x, y, button, istouch)
  if button == 1 and onLeftClick then
    onLeftClick(x, y)
  elseif button == 2 and onRightClick then
    onRightClick(x, y)
  end
end

function love.draw()
  camera:draw(function(l, t, w, h)
    map:draw()
  end)
end

function love.resize(w, h)
  width = w
  height = h
  map:resize(width, height)
  camera:setWindow(0, 0, width, height)
end

-- helper functions
function isRoad(x, y)
  local tile = getTile(tileCoords(x, y))
  return getType(tile) == 'Road'
end

function canPlaceRoad(x, y)
  local tile_x, tile_y = tileCoords(x, y)
  local adj_tiles = getAdjacentTiles(tile_x, tile_y)
  local adj_roads = _.filter(adj_tiles, function(tile) return getType(tile) == 'Road' end)
  return #adj_roads == 1
end

function placeRoad(x, y)
  local tile_x, tile_y = tileCoords(x, y)
  local prev_instance = getTileInstance(tile_x, tile_y)
  local new_tile = tilesetsByName['terrain'].tiles[169]

  -- update the live STI data that changes what is rendered
  map:swapTile(prev_instance, new_tile)

  -- update the layers data, which we're using
  map.layers['Terrain'].data[tile_y][tile_x] = {gid = new_tile.gid}
end

function getType(tile)
  return tilesets[tile.tileset].type
end

function getAdjacentTiles(tile_x, tile_y)
  return {
    getTile(tile_x - 1, tile_y),
    getTile(tile_x + 1, tile_y),
    getTile(tile_x, tile_y + 1),
    getTile(tile_x, tile_y - 1)
  }
end

function getTile(tile_x, tile_y)
  local tile = map.layers['Terrain'].data[tile_y][tile_x]
  return map.tiles[tile.gid]
end

function getTileInstance(tile_x, tile_y)
  local instance = map.layers['Terrain'].data[tile_y][tile_x]

  -- Go find actual instance
  local matching_instance
  for i, ins in ipairs(map.tileInstances[instance.gid]) do
    if ins.x == (tile_x - 1) * 20 and ins.y == (tile_y - 1) * 20 then
      matching_instance = ins
    end
  end
  return matching_instance
end

function tileCoords(x, y)
  x, y = camera:toWorld(x, y)
  local tile_x, tile_y = map:convertPixelToTile(x, y)
  return math.floor(tile_x) + 1, math.floor(tile_y) + 1
end


