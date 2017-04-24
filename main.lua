local anim8 = require('anim8')
local sti = require('sti')
local gamera = require('gamera')
local _ = require('underscore')
local Grid = require ("jumper.grid")
local Pathfinder = require ("jumper.pathfinder")
require('game')
--require('mobdebug').start()

local ver = '0.0.1'
local width, height
local camera
local music

local turret_img
local turret_frames = {}
local turrets = {}

local energy_img
local energy_frames = {}
local energy_sprites = {}
local energy_coords_to_frames = {
  below_right = 1,
  below_left = 2,
  below_above = 3,
  above_right = 4,
  right_left = 5,
  left_above = 6
}
local energy_coords_to_frames2 = {
  right_below = 1,
  left_below = 2,
  above_below = 3,
  right_above = 4,
  left_right = 5,
  left_above = 6
}

-- +1 b/c tiled is 0-based but Lua (& our pathfinder) is 1-based
local starports = {
  { x = 19+1, y = 24+1 },
  { x = 20+1, y = 74+1 },
  { x = 24+1, y = 2+1 },
  { x = 4+1, y = 3+1 },
  { x = 81+1, y = 15+1 },
  { x = 68+1, y = 74+1}
}

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

  energy_img = love.graphics.newImage('assets/energy.png')
  energy_frames[1] = love.graphics.newQuad(0, 0, 20, 20, energy_img:getDimensions())
  energy_frames[2] = love.graphics.newQuad(20, 0, 20, 20, energy_img:getDimensions())
  energy_frames[3] = love.graphics.newQuad(0, 20, 20, 20, energy_img:getDimensions())
  energy_frames[4] = love.graphics.newQuad(0, 40, 20, 20, energy_img:getDimensions())
  energy_frames[5] = love.graphics.newQuad(20, 40, 20, 20, energy_img:getDimensions())
  energy_frames[6] = love.graphics.newQuad(40, 40, 20, 20, energy_img:getDimensions())

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
    for i, energy in ipairs(energy_sprites) do
      love.graphics.draw(energy_img, energy.frame, energy.x, energy.y, 0, 1, 1)
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
  return #getAdjacentRoads(tile_x, tile_y) == 1 or (#getAdjacentRoads(tile_x, tile_y) == 2 and sameAlignment(getAdjacentRoads(tile_x, tile_y)))
end

function sameAlignment(adj_roads)
  return adj_roads[1].alignment == adj_roads[2].alignment
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
  local adj_roads = getAdjacentRoads(tile_x, tile_y)
  
  -- if we're connecting two adjacent roads (on either side)
  -- pay attention to the one whose image alignment doesn't match the alignment we're coming in at
  -- because that'll be a fork and needs its corners fixed
  local adj_road
  local adj_perp_road
  if adj_roads[2] and (getRoadAlignment(adj_roads[2]) ~= adj_roads[2].alignment) then
    adj_perp_road = adj_roads[2]
    adj_road = adj_roads[1]
  elseif adj_roads[2] then
    adj_perp_road = adj_roads[1]
    adj_road = adj_roads[2]
  else
    adj_perp_road = adj_roads[1]
    adj_road = adj_roads[1]
  end

  local adj_road_tile_ids = roads[terrain(adj_road)]
  
  if adj_road.alignment == 'vert' then
    if adj_road.id == adj_road_tile_ids.right then
      tile_x = tile_x - 1
    end

    -- the terrain is based on the adjacent tiles (could be different on each side of the road)
    placeTile(tile_x, tile_y, 'left', terrain(tile_x - 1, tile_y))
    placeTile(tile_x + 1, tile_y, 'right', terrain(tile_x + 2, tile_y))

    -- if the adjacent tile is horiz, this is a "fork" & we need to adjust the corner tiles
    if getRoadAlignment(adj_perp_road) == 'horiz' then
      if adj_perp_road.dir > 0 then
        placeTile(tile_x, tile_y + adj_perp_road.dir, 'top_left', terrain(tile_x - 1, tile_y))
        placeTile(tile_x + 1, tile_y + adj_perp_road.dir, 'top_right', terrain(tile_x + 2, tile_y))
      else
        placeTile(tile_x, tile_y + adj_perp_road.dir, 'bottom_left', terrain(tile_x - 1, tile_y))
        placeTile(tile_x + 1, tile_y + adj_perp_road.dir, 'bottom_right', terrain(tile_x + 2, tile_y))
      end
    end
  elseif adj_road.alignment == 'horiz' then
    if adj_road.id == roads[terrain(adj_road)].bottom then
      tile_y = tile_y - 1
    end
    placeTile(tile_x, tile_y, 'top', terrain(tile_x, tile_y - 1))
    placeTile(tile_x, tile_y + 1, 'bottom', terrain(tile_x, tile_y + 2))

    -- if the adjacent tile is vert, this is a "fork" & we need to also adjust the corner tiles
    if getRoadAlignment(adj_perp_road) == 'vert' then
      if adj_perp_road.dir > 0 then
        placeTile(tile_x + adj_perp_road.dir, tile_y, 'top_left', terrain(tile_x, tile_y - 1))
        placeTile(tile_x + adj_perp_road.dir, tile_y + 1, 'bottom_left', terrain(tile_x, tile_y + 2))
      else
        placeTile(tile_x + adj_perp_road.dir, tile_y, 'top_right', terrain(tile_x, tile_y - 1))
        placeTile(tile_x + adj_perp_road.dir, tile_y + 1, 'bottom_right', terrain(tile_x, tile_y + 2))
      end
    end
  end

  updatePathsToStarports()
end

-- can also take a single tile arg: `tileIDs(tile)`
function terrain(tile_x, tile_y)
  local tile
  if type(tile_x) == 'table' then
    tile = tile_x
  else
    tile = getTile(tile_x, tile_y)
  end

  local terrain_type
  if not tile then
    warn('no tile found')
  else
    local props = tile.properties
    if not props then
      warn('tile has no properties: ' .. tile)
    else
      if not props.terrain_type then
        warn('tile has no terrain_type: ' .. tile.id)
      else
        terrain_type = props.terrain_type
      end
    end
  end

  if terrain_type then
    return terrain_type
  else
    return 'ice'
  end
end

function getRoadAlignment(tile)
  local terrain_type = terrain(tile)
  local tile_ids = roads[terrain_type]

  local tile_id = tile.id
  if tile_id == tile_ids.left or tile_id == tile_ids.right then
    return 'vert'
  elseif tile_id == tile_ids.top or tile_id == tile_ids.bottom then
    return 'horiz'
  else
    warn('tile_id ' .. tile_id .. ' not found in IDs for terrain ' .. terrain_type .. ': ' .. printShallow(tile_ids))
    return 'vert' -- default
  end
end

function placeTile(tile_x, tile_y, tile_pos, terrain_type)
  local tiles = tilesetsByName['terrain'].tiles
  local new_tile = tiles[roads[terrain_type][tile_pos]]
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

function updatePathsToStarports()
  energy_sprites = {}
  local grid = Grid(buildRoadMap())
  local finder = Pathfinder(grid, 'ASTAR', 1) -- i saw strange jumping issues w/ JPS
  finder:setMode('ORTHOGONAL') -- we don't allow diagonal

  -- reset working state
  for i, starport in ipairs(starports) do
    starport.working = false
    starport.connected = false
  end
  starports[1].working = true

  -- don't recurse immediately into every possible path
  -- instead, only take the shortest path
  -- from there, add more potential paths to the arsenal
  -- but again, only take the shortest path -- whether that's a path that was just discovered or a previous one
  local paths = {}
  function checkPaths(starport)
    for i, other in ipairs(starports) do
      if other ~= starport then
        local path = finder:getPath(starport.x, starport.y, other.x, other.y)
        if path then
          local len = path:getLength()
          table.insert(paths, {start = starport, stop = other, path = path, len = len})
        end
      end
    end

    -- each time filter to ones that haven't been turned on yet
    -- sorted by the distance
    paths = _.filter(paths, function(path)
      return path.stop.working == false
    end)
    table.sort(paths, compareByLen)

    local path = paths[1]
    if path then
      path.stop.working = true
      addEnergySprites(path.path, path.start, path.stop)
      checkPaths(path.stop)
    end
  end

  checkPaths(starports[1])

  function compareByLen(a,b)
    return a.len < b.len
  end
end

function addEnergySprites(path, start, stop)
  -- transform their iterator into a normal array
  -- this is necessary so I can easily look at the next & prev items
  local nodes = {}
  for node, count in path:nodes() do
    node = { x = node:getX(), y = node:getY() }
    table.insert(nodes, node)
    print(node.x, node.y)
  end

  for i, node in ipairs(nodes) do
    local prev_coords = getCoords(nodes[i - 1], node)
    local next_coords = getCoords(nodes[i + 1], node)
    print(node.x, node.y, '(prev:', prev_coords, ', next:', next_coords, ')')
    local coords_ix = prev_coords and next_coords and (prev_coords .. '_' .. next_coords)
    print('coords_ix: ', coords_ix)
    local frame_ix = energy_coords_to_frames[coords_ix] or energy_coords_to_frames2[coords_ix]
    if frame_ix then
      table.insert(energy_sprites, {
        x = (node.x - 1) * 20, -- -1 b/c we're switching from 1-based lua to 0-based screen
        y = (node.y - 1) * 20,
        frame = energy_frames[frame_ix]
      })
    end
  end
end

function getCoords(prev_next, node)
  if not prev_next then
    return -- don't render the start or end tile b/c these would render on top of a starbase
  end

  local x = prev_next.x - node.x
  local y = prev_next.y - node.y
  if x == -1 then
    return 'left'
  elseif x == 1 then
    return 'right'
  elseif y == -1 then
    return 'above'
  elseif y == 1 then
    return 'below'
  else
    print('non-adjacent nodes returned by pathfinder: ' .. x .. ', ' .. y)
  end
end

-- the kind of 0 and 1 map required by the Jumper pathfinder lib
function buildRoadMap()
  local terrain_data = map.layers['Terrain'].data
  local pathmap = {}
  for tile_y, row in ipairs(terrain_data) do
    local map_row = {}
    table.insert(pathmap, map_row)
    for tile_x, tile in ipairs(row) do
      local val
      if tile then
        val = getType(map.tiles[tile.gid]) == 'road' and 1 or 0
      else
        val = 0
      end
      -- if (tile_x == 20 and tile_y == 74) or (tile_x == 19 and tile_y == 24) then
      --   io.write(tostring(val) .. '*')
      -- else
      --   io.write(tostring(val) .. ' ')
      -- end
      table.insert(map_row, val)
    end
    -- io.write('\n')
  end
  return pathmap
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

function shallowCopyArray(orig)
  copy = {}
  for orig_key, orig_value in ipairs(orig) do
      copy[orig_key] = orig_value
  end
  return copy
end

function table.slice(tbl, first, last)
  local sliced = {}
  for i = first or 1, last or #tbl do
    table.insert(sliced, tbl[i])
  end
  return sliced
end
