local anim8 = require('anim8')
local sti = require('sti')
local gamera = require('gamera')
local _ = require('underscore')
require('game')
--require('mobdebug').start()

local ver = '0.0.1'
local width, height
local camera
local music

local turret_img
local turret_frames = {}
local turrets = {}

local fireballs = {}
local fireball_img
local fireball_speed = 500
local direction = {}
local init_position = {}

local fighters = {}
local fighter_img
local fighter_speed = 200
local next_fighter_attack = love.timer.getTime() + 3 -- in 10 seconds, first fighter attack
local min_time_btwn_attacks = 30 -- seconds
local max_time_btwn_attacks = 90 -- seconds

local map
local auto_scroll_region = 0.12 -- 12% of the width/height on all sides of window
local auto_scroll_speed = 500
local tilesetsByName = {}
local types = {'ice', ''}
local zoom = 2.0

local roads = {
  ice = {
    offset = 0,
    top = 184,
    left = 195,
    right = 197,
    bottom = 208,
    bottom_right = 220,
    bottom_left = 221,
    top_right = 232,
    top_left = 233,
    top_destr_right = 186,
    top_destr_left = 187,
    left_destr_bottom = 188,
    right_destr_bottom = 189,
    bottom_destr_right = 198,
    bottom_destr_left = 199,
    left_destr_top = 200,
    right_destr_top = 201
  },
  grass = { offset = -183 },
  crater = { offset = -123 },
  lava = { offset = 120 },
  water = { offset = 300},
  tech = { offset = 357},
  mountain = { offset = 441}
}
for type, road_type in pairs(roads) do
  local offset = road_type.offset
  for key, val in pairs(roads.ice) do
    if key ~= 'offset' then
      road_type[key] = val + offset
      print(type, key, val + offset)
    end
  end
end

-- GLOBALS shared w/ game.lua
active_turret = nil

function love.load()
  love.graphics.setDefaultFilter( 'nearest', 'nearest' )
  love.window.setTitle('One Golden Sun ' .. ver)
  width, height = love.graphics.getDimensions()
  love.window.setMode(width, height, {resizable=true, vsync=false, minwidth=400, minheight=300})
  camera = gamera.new(0, 0, 2000, 2000) -- TODO: pull this from the map?
  camera:setScale(zoom)

  music = love.audio.newSource('assets/intro.mp3')
  music:play()

  fighter_img = love.graphics.newImage('assets/enemy-ship.png')
  fireball_img = love.graphics.newImage('assets/fireball.png')
  turret_img = love.graphics.newImage('assets/turret.png')
  turret_frames[1] = love.graphics.newQuad(80, 0, 80, 80, turret_img:getDimensions())
  direction[1] = {0, -1}
  init_position[1] = {-0.1, -1.5}
  turret_frames[2] = love.graphics.newQuad(80, 80, 80, 80, turret_img:getDimensions())
  direction[2] = {1, -1}
  init_position[2] = {0.85, -1.1}
  turret_frames[3] = love.graphics.newQuad(80, 160, 80, 80, turret_img:getDimensions())
  direction[3] = {1, -0.5}
  init_position[3] = {1, -0.7}
  turret_frames[4] = love.graphics.newQuad(80, 240, 80, 80, turret_img:getDimensions())
  direction[4] = {1, 0.5}
  init_position[4] = {1, 0.2}
  turret_frames[5] = love.graphics.newQuad(0, 0, 80, 80, turret_img:getDimensions())
  direction[5] = {0, 0.8}
  init_position[5] = {-0.1, 0.8}
  turret_frames[6] = love.graphics.newQuad(0, 240, 80, 80, turret_img:getDimensions())
  direction[6] = {-1, 0.5}
  init_position[6] = {-1, 0.2}
  turret_frames[7] = love.graphics.newQuad(0, 160, 80, 80, turret_img:getDimensions())
  direction[7] = {-1, -0.5}
  init_position[7] = {-1, -0.7}
  turret_frames[8] = love.graphics.newQuad(0, 80, 80, 80, turret_img:getDimensions())
  direction[8] = {-1, -1}
  init_position[8] = {-1, -1.1}

  map = sti('world2.lua', {'bump'})
  local tilesets = {}
  for i, tileset in ipairs(map.tilesets) do
    local name = tileset.image_filename:gsub('assets/', ''):gsub('.png', '')
    local tileset_info = { tiles = {} }
    tilesets[i] = tileset_info
    tilesetsByName[name] = tileset_info
  end
  for i, tile in ipairs(map.tiles) do
    tilesets[tile.tileset].tiles[tile.id] = tile
  end
end

function love.update(dt)
  if love.timer.getTime() > next_fighter_attack then
    startFighterAttack()
    next_fighter_attack = love.timer.getTime() + love.math.random(min_time_btwn_attacks, max_time_btwn_attacks)
  end

  map:update(dt)
  mouse_x, mouse_y = love.mouse.getPosition()
  if whileMouseDown and love.mouse.isDown(1) then
    whileMouseDown(mouse_x, mouse_y)
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

  local entity_tables = {fireballs, fighters}
  for i, ent_table in ipairs(entity_tables) do
    for i, entity in ipairs(ent_table) do
      entity.x = entity.x + entity.dx * fireball_speed * dt
      entity.y = entity.y + entity.dy * fireball_speed * dt
    end
  end
end

function love.keypressed(key, scancode, isrepeat)
  if onLeft and (key == 'left' or key == 'a') then
    onLeft()
  elseif onRight and (key == 'right' or key == 'd') then
    onRight()
  elseif onUp and (key == 'up' or key == 'w') then
    onUp()
  elseif onDown and (key == 'down' or key == 's') then
    onDown()
  elseif onSpace and (key == 'space') then
    onSpace()
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
    for i, turret in ipairs(turrets) do
      -- wrap-around frames, protect against bad inputs from game.lua
      if turret.frame < 1 then
        turret.frame = #turret_frames
      elseif turret.frame > #turret_frames then
        turret.frame = 1
      end

      love.graphics.draw(turret_img, turret_frames[turret.frame], turret.x * 20, turret.y * 20, 0, 1, 1)
    end
    for i, fireball in ipairs(fireballs) do
      love.graphics.draw(fireball_img, fireball.x, fireball.y)
    end
    for i, fighter in ipairs(fighters) do
      love.graphics.draw(fighter_img, fighter.x, fighter.y)
    end
  end)
end

function love.resize(w, h)
  width = w
  height = h
  map:resize(width, height)
  camera:setWindow(0, 0, width, height)
end

-- helper functions
function startFighterAttack()
  local dx = love.math.random(-1, 1)
  local dy
  if dx == 0 then
    local options = {-1, 1} -- don't allow 0 if dx is 0
    dy = options[love.math.random(1, 2)]
  else
    dy = love.math.random(-1, 1)
  end

  -- put the fighter just offscreen, so that it'll move on-screen
  local cam_x, cam_y = camera:getPosition()
  local x
  if dx > 0 then
    x = cam_x
  elseif dx < 0 then
    x = cam_x + width
  elseif dx == 0 then
    x = cam_x + (width / 2)
  end

  local y
  if dy > 0 then
    y = cam_y
  elseif dy < 0 then
    y = cam_y + height
  elseif dy == 0 then
    y = cam_y + height / 2
  end

  table.insert(fighters, {
    x = x,
    y = y,
    dx = dx,
    dy = dy
  })
end

function fireMissile(active_turret)
  local fireball = {
    x = (active_turret.x + 2) * 20, -- the center point of the turret is 2,2 in tiles
    y = (active_turret.y + 2) * 20,
    dx = direction[active_turret.frame][1],
    dy = direction[active_turret.frame][2]
  }

  -- move the fireball from the center of the turret to the muzzle,
  -- so it looks like it's coming from the gun
  fireball.x = fireball.x + init_position[active_turret.frame][1] * 30
  fireball.y = fireball.y + init_position[active_turret.frame][2] * 30
  table.insert(fireballs, fireball)
end

function isRoad(x, y)
  return getType(getTile(tileCoords(x, y))) == 'road'
end

function canPlaceRoad(x, y)
  local tile_x, tile_y = tileCoords(x, y)
  return #getAdjacentRoads(tile_x, tile_y) == 1
end

function canPlaceTurret(x, y)
  if isRoad(x, y) then
    return false
  end

  local tile_x, tile_y = tileCoords(x, y)
  return #getAdjacentRoads(tile_x, tile_y) == 0 and
    #getAdjacentRoads(tile_x + 1, tile_y) == 0 and
    #getAdjacentRoads(tile_x, tile_y - 1) == 0 and
    #getAdjacentRoads(tile_x + 1, tile_y - 1) == 0
end

function placeTurret(x, y)
  local tile_x, tile_y = tileCoords(x, y)
  active_turret = {x = tile_x - 2, y = tile_y - 3, frame = 2}
  table.insert(turrets, active_turret)
end

function placeRoad(x, y)
  local tile_x, tile_y = tileCoords(x, y)
  local adj_road = getAdjacentRoads(tile_x, tile_y)[1]
  local adj_tile = getAdjacentNonRoads(tile_x, tile_y)[1]
  local tiles = tilesetsByName['terrain'].tiles

  local road_type = getTerrainType(adj_tile)
  local tile_ids = roads[road_type]
  
  -- this is if the orientations match, this is easy
  if adj_road.alignment == 'vert' then
    if adj_road.id == tile_ids.right then
      tile_x = tile_x - 1
    end
    placeTile(tiles[tile_ids.left], tile_x, tile_y)
    placeTile(tiles[tile_ids.right], tile_x + 1, tile_y)

    -- if the adjacent tile is horiz, this is a "fork" & we need to adjust the corner tiles
    if isHorizontal(adj_road, tile_ids) then
      placeTile(tiles[adj_road.dir > 0 and tile_ids.top_left or tile_ids.bottom_left], tile_x, tile_y + adj_road.dir)
      placeTile(tiles[adj_road.dir > 0 and tile_ids.top_right or tile_ids.bottom_right], tile_x + 1, tile_y + adj_road.dir)
    end 
  elseif adj_road.alignment == 'horiz' then
    if adj_road.id == tile_ids.bottom then
      tile_y = tile_y - 1
    end
    placeTile(tiles[tile_ids.top], tile_x, tile_y)
    placeTile(tiles[tile_ids.bottom], tile_x, tile_y + 1)

    -- if the adjacent tile is vert, this is a "fork" & we need to also adjust the corner tiles
    if isVertical(adj_road, tile_ids) then
      placeTile(tiles[adj_road.dir > 0 and tile_ids.top_left or tile_ids.top_right], tile_x + adj_road.dir, tile_y)
      placeTile(tiles[adj_road.dir > 0 and tile_ids.bottom_left or tile_ids.bottom_right], tile_x + adj_road.dir, tile_y + 1)
    end
  end
end

function getTerrainType(tile)
  local props = tile.properties
  if not props then
    return warn('tile has no properties: ' .. tile)
  end
  if not props.terrain_type then
    return warn('tile has no terrain_type: ' .. tile.id)
  end
  return props.terrain_type
end

function isVertical(tile, tile_ids)
  return tile.id == tile_ids.left or tile.id == tile_ids.right
end

function isHorizontal(tile, tile_ids)
  return tile.id == tile_ids.top or tile.id == tile_ids.bottom
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

function getAdjacentNonRoads(tile_x, tile_y)
  local adj_tiles = getAdjacentTiles(tile_x, tile_y)
  local adj_non_roads = {}
  for i, tile in ipairs(adj_tiles) do
    if getType(tile) == 'road' then
      table.insert(adj_non_roads, tile)
    end
  end
  return adj_non_roads
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

-- generic helper functions
function warn(str)
  print('WARNING: ' .. str .. '\n' .. debug.traceback())
end

function printShallow(tbl)
  str = '{ '
  for k, v in pairs(tbl) do
    str = str .. k .. ': ' .. v .. ', '
  end
  str = str .. ' }'
  return str
end
