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


g = grid.connect()

engine.name="MxSynths"
local mxsynths_=include("mx.synths/lib/mx.synths")
local notelength = 3



-- voicing

function trigger(note_num, hz, voice)
  engine.mx_note_on(note_num,1,notelength)
end

function gate_high(note_num, hz, voice)
  engine.mx_note_on(note_num,1,6)
end

function gate_low(note_num, hz, voice)
  engine.mx_note_off(note_num)
end
  
-- core stuff

function init()
  meadowphysics.init()
  mxsynths=mxsynths_:new()
  params:add_separator()
  cs_AMP = controlspec.new(0,60,'lin',0,0.1,'')
  params:add{
    type="control",id="note length",controlspec=cs_AMP,
    action=function(x) notelength = x end
  }
  
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
