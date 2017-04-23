-- high-level game logic is here
function onLeftClick(x, y)
  if not isRoad(x, y) then
    if (canPlaceRoad(x, y)) then
      placeRoad(x, y)
    end
  end
end
