local anim8 = require('anim8')
local sti = require('sti')
local ver = '0.0.1'
local width, height

-- draw everything to a canvas so we can do linear/nearest-neightbor rescaling
-- https://love2d.org/forums/viewtopic.php?t=7911#p49010
local canvas

function love.load()
  love.window.setTitle('One Golden Sun ' .. ver)
  width, height = love.graphics.getDimensions()
  love.window.setMode(width, height, {resizable=true, vsync=false, minwidth=400, minheight=300})
  canvas = love.graphics.newCanvas(width / 2, height / 2)
  canvas:setFilter("nearest", "nearest")

  map = sti("world.lua", {"bump"})
end

function love.draw()
  love.graphics.setCanvas(canvas) --This sets the draw target to the canvas
  map:draw()
  love.graphics.setCanvas() --This sets the target back to the screen
  love.graphics.draw(canvas, 0, 0, 0, 2, 2)
end

function love.resize(w, h)
  width = w
  height = h
  map:resize(w, h)
  canvas = love.graphics.newCanvas(width / 2, height / 2)
end
