--
--   m e a d o w p h y s i c s
--
--   a grid-enabled
--   rhizomatic
--   cascading counter
--
--
--   *----
--        *-----
--            *---
--      *-----
--
--

local meadowphysics = include("meadowphysics/lib/mp/core")()
local hs = include('lib/halfsecond')

g = grid.connect()

engine.name="MxSynths"
local mxsynths_=include("mx.synths/lib/mx.synths")
mxsynths=mxsynths_:new()


-- voicing

function trigger(note_num, hz, voice)
  engine.mx_note_on(note_num,1,60)
end

function gate_high(note_num, hz, voice)
  engine.mx_note_on(note_num,1,60)
end

function gate_low(note_num, hz, voice)
  engine.mx_note_on(note_num,1,60)
end



-- core stuff

function init()
  meadowphysics.init()
end

function key(n,z)
  meadowphysics:handle_key(n,z)
end

function g.key(x, y, z) 
  meadowphysics:handle_grid_input(x, y, z)
end

function redraw()
  screen.clear()
  meadowphysics:draw()
  screen.update()
end
