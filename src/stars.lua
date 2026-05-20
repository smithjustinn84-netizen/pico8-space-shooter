-- stars.lua
-- background starfield parallax engine

function init_stars()
  stars = {}
  for i = 1, 20 do
    local r = rnd(1)
    local spd, col
    if r > 0.9 then
      spd, col = 1.2 + rnd(0.5), 7
    elseif r > 0.6 then
      spd, col = 0.6 + rnd(0.4), 6
    else
      spd, col = 0.2 + rnd(0.3), 5
    end
    add(
      stars, {
        x = rnd(128), y = rnd(128), speed = spd, col = col,
        update = function(s)
          s.y += s.speed
          if s.y > 128 then
            s.y = 0
            s.x = rnd(128)
          end
        end,
        draw = function(s)
          pset(s.x, s.y, s.col)
        end
      }
    )
  end
end

function update_stars()
  for s in all(stars) do
    s.update(s)
  end
end

function draw_stars()
  for s in all(stars) do
    s.draw(s)
  end
end
