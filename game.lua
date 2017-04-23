-- high-level game logic
function whileMouseDown(x, y)
  if not isRoad(x, y) then
    if (canPlaceRoad(x, y)) then
      placeRoad(x, y)
    end
  end
end

function onRightClick(x, y)
  if (canPlaceTurret(x, y)) then
    print('can place turret')
    placeTurret(x, y)
  else
    print('can NOT place turret')
  end
end

function onLeft()
  if active_turret then
    active_turret.frame = active_turret.frame - 1
  end
end

function onRight()
  if active_turret then
    active_turret.frame = active_turret.frame + 1
  end
end

function onSpace()
  if active_turret then
    fireMissile(active_turret)
  end
end