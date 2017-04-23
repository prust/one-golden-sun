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
local zoom = 2.0

function love.load()
  love.graphics.setDefaultFilter( 'nearest', 'nearest' )
  love.window.setTitle('One Golden Sun ' .. ver)
  width, height = love.graphics.getDimensions()
  love.window.setMode(width, height, {resizable=true, vsync=false, minwidth=400, minheight=300})
  camera = gamera.new(0, 0, 2000, 2000) -- TODO: pull this from the map?
  camera:setScale(zoom)

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
  if whileLeftMouseDown and love.mouse.isDown(1) then
    whileLeftMouseDown(mouse_x, mouse_y)
  end

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

function love.wheelmoved(x, y)
  if y > 0 then
    zoom = 2.0
  elseif y < 0 then
    zoom = 1.0
  end
  if y ~= 0 then
    camera:setScale(zoom)
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
  return getType(getTile(tileCoords(x, y))) == 'road'
end

function canPlaceRoad(x, y)
  local tile_x, tile_y = tileCoords(x, y)
  return #getAdjacentRoads(tile_x, tile_y) == 1
end

function placeRoad(x, y)
  local tile_x, tile_y = tileCoords(x, y)
  local adj_road = getAdjacentRoads(tile_x, tile_y)[1]
  local tiles = tilesetsByName['terrain'].tiles
  
  -- this is if the orientations match, this is easy
  if adj_road.alignment == 'vert' then
    if adj_road.id == 181 then
      tile_x = tile_x - 1
    end
    placeTile(tiles[179], tile_x, tile_y)
    placeTile(tiles[181], tile_x + 1, tile_y)

    -- if the adjacent tile is horiz, this is a "fork" & we need to adjust the corner tiles
    if isHorizontal(adj_road) then
      placeTile(tiles[adj_road.dir > 0 and 214 or 203], tile_x, tile_y + adj_road.dir)
      placeTile(tiles[adj_road.dir > 0 and 213 or 202], tile_x + 1, tile_y + adj_road.dir)
    end 
  elseif adj_road.alignment == 'horiz' then
    if adj_road.id == 191 then
      tile_y = tile_y - 1
    end
    placeTile(tiles[169], tile_x, tile_y)
    placeTile(tiles[191], tile_x, tile_y + 1)

    -- if the adjacent tile is vert, this is a "fork" & we need to also adjust the corner tiles
    if isVertical(adj_road) then
      placeTile(tiles[adj_road.dir > 0 and 214 or 213], tile_x + adj_road.dir, tile_y)
      placeTile(tiles[adj_road.dir > 0 and 203 or 202], tile_x + adj_road.dir, tile_y + 1)
    end
  end
end

function isVertical(tile)
  return tile.id == 179 or tile.id == 181
end

function isHorizontal(tile)
  return tile.id == 169 or tile.id == 191
end

function placeTile(new_tile, tile_x, tile_y)
  local prev_instance = getTileInstance(tile_x, tile_y)
  if not prev_instance then
    return
  end

  -- update the live STI data that changes what is rendered
  map:swapTile(prev_instance, new_tile)

  -- update the layers data, which we're using
  map.layers['Terrain'].data[tile_y][tile_x] = {gid = new_tile.gid}
end

function getType(tile)
  return tile and tile.properties and tile.properties.type
end

function getAdjacentRoads(tile_x, tile_y)
  local adj_tiles = getAdjacentTiles(tile_x, tile_y)
  local adj_roads = {}
  for i, tile in ipairs(adj_tiles) do
    if getType(tile) == 'road' then
      table.insert(adj_roads, tile)
      if i == 1 or i == 2 then
        tile.alignment = 'horiz'
      else
        tile.alignment = 'vert'
      end

      if i == 1 then
        tile.dir = -1
      elseif i == 2 then
        tile.dir = 1
      elseif i == 3 then
        tile.dir = -1
      elseif i == 4 then
        tile.dir = 1
      end
    end
  end
  return adj_roads
end

-- TODO: add bounds-checks & don't get the tile if it's off the edge of the map
function getAdjacentTiles(tile_x, tile_y)
  return {
    getTile(tile_x - 1, tile_y),
    getTile(tile_x + 1, tile_y),
    getTile(tile_x, tile_y - 1),
    getTile(tile_x, tile_y + 1),
  }
end

function getTile(tile_x, tile_y)
  local terrain_data = map.layers['Terrain'].data
  if terrain_data[tile_y] then
    local tile = terrain_data[tile_y][tile_x]
    return tile and map.tiles[tile.gid]
  end
end

function getTileInstance(tile_x, tile_y)
  local terrain_data = map.layers['Terrain'].data
  if terrain_data[tile_y] then
    local instance = terrain_data[tile_y][tile_x]

    -- Go find actual instance
    local matching_instance
    for i, ins in ipairs(map.tileInstances[instance.gid]) do
      if ins.x == (tile_x - 1) * 20 and ins.y == (tile_y - 1) * 20 then
        matching_instance = ins
      end
    end
    return matching_instance
  end
end

function tileCoords(x, y)
  x, y = camera:toWorld(x, y)
  local tile_x, tile_y = map:convertPixelToTile(x, y)
  return math.floor(tile_x) + 1, math.floor(tile_y) + 1
end


