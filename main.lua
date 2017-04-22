local anim8 = require 'anim8'
local sti = require "sti"

function love.load()
  map = sti("world.lua", {"bump"})
end

function love.draw()
  map:draw()
end
