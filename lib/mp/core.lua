--

local function Meadowphysics ()

  local mp = {}

  local create_voice = include("meadowphysics/lib/mp/voice")
  local setup_params = include("meadowphysics/lib/mp/parameters")
  local ui = include("meadowphysics/lib/mp/ui")
  local mp_grid = include("meadowphysics/lib/mp/grid")
  local scale = include("meadowphysics/lib/mp/scale")
  local MusicUtil = require "musicutil"

  mp.ppqn = 96

  -- focus
  -- focus sets what draws to screen, grid, what key presses mean, and what grid presses mean
  --
  -- * HOME: default state showing the lenths of each track etc
  -- * RESETS: for setting reset actions, playing state, gate/trig etc
  -- * RULES: for setting reset rules
  -- * TIME: clock division etc
  -- * CONFIG: meadowphysics global config
  -- * ALT: my additions, when holding key 1
  mp.focus = "HOME"
  mp.state = {
    dirty = true,
    grid_keys = {},
    selected_voice = 1
  }
  -- create an empty table of grid key states
  for i = 1, 8 do
    mp.state.grid_keys[i] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
  end

  mp.midi_out_device = midi.connect(1)
  
  local mp_ui = ui.new(mp)

  local voices = {}
  mp.voices = voices

  mp.init = function ()
    mp.voice_count = 8
    setup_params(mp)
    scale:make_params()


    -- set up each voice

    for i=1,mp.voice_count do
      voices[i] = create_voice(i, mp)
      local voice = voices[i]
      voice.on_bang = function ()
        -- either use note from scale, or override from params
        local note_num = scale.notes[mp.voice_count + 1 - i]
        if params:get(i .. "_note") ~= 1 then
          note_num = params:get(i .. "_note") - 1
        end
        -- generate note/hz
        local hz = MusicUtil.note_num_to_freq(note_num)
        -- if the voice type is a trigger
        if params:get(i .. "_type") == 1 then

          if (params:get('output') == 1 or params:get('output') == 3) then
            trigger(note_num, hz, i) -- global defined by main script
          end

          if (params:get('output') == 2 or params:get('output') == 3) then
            midi_note_on(i)
          end

          if (params:get('output') == 4) then
            crow.output[util.wrap(i, 1, 4)].volts = 10
            crow.output[util.wrap(i, 1, 4)].volts = 0
          end

          if params:get('output') == 5 then
            crow.ii.jf.play_note((note_num-60) / 12, 5 )
          end

          if params:get('output') == 6 then
            crow.ii.jf.vtrigger( voice.index, 8)
          end
        end
        -- If the voice type is a gate
        if params:get(i .. "_type") == 2 then
          if(voice.gate == 1) then
            if (params:get('output') == 1 or params:get('output') == 3) then
              gate_high(note_num, hz, i) -- global defined by main script
            end
            if (params:get('output') == 2 or params:get('output') == 3) then
              midi_note_on(i)
            end
          else
            if (params:get('output') == 1 or params:get('output') == 3) then
              gate_low(note_num, hz, i) -- global defined by main script
            end
            if (params:get('output') == 2 or params:get('output') == 3) then
              midi_note_off(i)
            end
          end
        end
      end
    end

    -- setup beat clock

    -- function clock.transport.start() mp.clock_id = clock.run(mp.clock_loop) end
    -- function clock.transport.stop()
    --   clock.cancel(mp.clock_id)
    --   print("stop clock")
    -- end
    -- clock.transport.start()
    -- mp.master_clock = nil

    function clock.transport.start()
      print("start transport")
      -- mp.clock_id = clock.run(mp.clock_loop)
      -- mp.reset()
      mp.paused = false
    end

    function clock.transport.stop()
      -- clock.cancel(mp.clock_id)
      mp.paused = true
      print('stop transport')
    end

    mp.clock_id = clock.run(mp.clock_loop)


  end

  function get_midi_target(track)
    local channel = 1
    if params:get(track .. "_midi_channel") == 1 then
      channel = params:get("midi_out_channel")
    else
      channel = params:get(track .. "_midi_channel") - 1
    end
    local note = 1
    if params:get(track .. "_note") == 1 then
      note = scale.notes[track]
    else
      note = params:get(track .. "_note") - 1
    end
    return channel, note
  end

  function midi_note_on(track)
    local channel, note = get_midi_target(track)
    print(track, note, channel)
    voices[track].active_midi_notes[note] = true
    mp.midi_out_device:note_on(note, 100, channel)
  end

  function midi_note_off(track)
    local channel, note = get_midi_target(track)
    mp.midi_out_device:note_off(note, 100, channel)
    voices[track].active_midi_notes[note] = nil
  end

  notes = {} -- @todo this is used by scale but it's weird like this. fix it.

  function mp.all_notes_off()
    for i = 1, mp.voice_count do
      if (params:get(i.."_type") == 1) then midi_note_off(i) end
      for k,v in pairs(voices[i].active_midi_notes) do
        print("note off", k,v)
      end
    end
  end

  mp.clock_loop = function()
    while true do
      clock.sync(1/(params:get("clock_division")*4))
      if (params:get('output') == 2 or params:get('output') == 3 and false) then
        mp.all_notes_off()
      end
      mp.handle_tick()
      redraw()
      mp_grid:draw(mp)
    end
  end

  -- Clock Loop
  function mp:handle_tick()
    if mp.paused then return end
    -- triggers
    for i=1,mp.voice_count do
      if voices[i].current_tick == voices[i].current_clock_division and voices[i].current_step == 1  then
        voices[i].bang()
      end
    end
    -- resets
    for i=1,mp.voice_count do
      voices[i].apply_resets()
    end
    -- increment current tick for each voice
    for i=1,mp.voice_count do
      voices[i].current_tick = voices[i].current_tick+1
    end
  end


  function mp:playpause ()
    mp.all_notes_off()
    if mp.paused then 
      mp.paused = false 
    else
      mp.paused = true
    end
  end
  
  function mp:reset () 
    mp.all_notes_off()
    for i=1,mp.voice_count do
      voices[i].reset()
    end
    print "reset"
  end


  --
  --  norns hardware keys and encoders
  --
  function mp:handle_key (n, z)
    -- home
    if mp.focus == "HOME" then
      if n == 1 and z == 1 then
        print("enter alt focus")
        mp.focus = "ALT"
      end
      if n == 2 and z == 1 then
        print("enter time focus")
        mp.focus = "TIME"
      end
      if n == 3 and z == 1 then
        print("enter config focus")
        mp.focus = "CONFIG"
      end
    end
    -- resets
    if mp.focus == "RESETS" then

    end
    -- rules
    if mp.focus == "RULES" then

    end
    -- config
    if mp.focus == "CONFIG" then
      if n == 3 and z == 0 then
        print("exit config focus")
        mp.focus = "HOME"
      end
    end
    -- time
    if mp.focus == "TIME" then
      if n == 2 and z == 0 then
        print("exit time focus")
        mp.focus = "HOME"
      end
    end
    -- alt
    if mp.focus == "ALT" then
      if n == 1 and z == 0 then
        print("exit alt focus")
        mp.focus = "HOME"
      end
      if n == 2 and z == 1 then
        mp:playpause()
      end
      if n == 3 and z == 1 then
        mp:reset()
      end
    end
    redraw()
    mp_grid:draw(mp)
  end


  --
  -- grid keys
  --

  function mp:handle_grid_input(x, y, z)
    -- update grid key state
    mp.state.grid_keys[y][x] = z

    --  home mode
    if mp.focus == "HOME" then
      -- navigate to resets mode if first column is pressed
      if x == 1 and z == 1 then
        mp.state.selected_voice = y
        mp.focus = "RESETS"
      end
      -- apply track range
      if x > 1 and z == 1 then
        -- determine upper and lower range bounds
        local row_pressed_keys = {}
        -- loop through the row of this key and look for other pressed keys
        -- to determine a range
        for i=2, 16 do
          if mp.state.grid_keys[y][i] == 1 then
            table.insert(row_pressed_keys, i)
          end
        end
        -- apply range
        params:set(y .. "_range_low", row_pressed_keys[1])
        params:set(y .. "_range_high", row_pressed_keys[#row_pressed_keys])
        -- reset voice with single key press
        if #row_pressed_keys == 1 then
          voices[y].current_step = x
          voices[y].current_tick = 0
          voices[y].current_cycle_length = x
          params:set(y .. "_range_high", x)
          params:set(y .. "_range_low", x)
          params:set(y .. "_running", 2)
          voices[y].bang()
        end
      end
    end

    --  resets mode
    if mp.focus == "RESETS" then
      -- navigation
      if x == 2 and z == 1 then
        mp.focus = "RULES"
      end
      if x == 1 and z == 0 then
        mp.focus = "HOME"
      end
      -- voice options
      if z == 1 then
        -- toggle playback of voice
        if (x == 3) then
          mp.voices[y].toggle_playback()
        end
        -- set voice to be reset by selected voice
        if (x == 4) then
          mp.voices[mp.state.selected_voice].toggle_target(y)
        end
        -- set trig or gate mode
        if (x == 6) then
          mp.voices[y].set_bang_type(1)
        end
        if (x == 7) then
          mp.voices[y].set_bang_type(2)
        end
        if (x > 8) then
          -- Get the highest and lowest division keys pressed
          local pushed_division_keys = {}
          for di=1,8 do
            if (mp.state.grid_keys[y][di+8]) == 1 then
              table.insert(pushed_division_keys, di)
            end
          end
          params:set(y .. "_clock_division_low", pushed_division_keys[1])
          params:set(y .. "_clock_division_high", pushed_division_keys[#pushed_division_keys])
          mp.voices[y].current_clock_division = pushed_division_keys[1]
        end
      end
    end

    --  rules mode
    if mp.focus == "RULES" then
      -- navigation
      if x == 1 and z == 0 then
        mp.focus = "HOME"
      end
      if x == 2 and z == 0 then
        mp.focus = "RESETS"
      end
      if z == 1 then
        -- set rule
        if x > 8 then
          local rules = {"none", "increment", "decrement", "min", "max", "random", "pole", "stop"} -- @todo this is duplicated
          params:set(mp.state.selected_voice .. "_rule", y)
        end
        -- apply rule to voice/reset/clock/etc
        if x > 4 and x < 8 then
          params:set(mp.state.selected_voice .. "_rule_target", y)
          params:set(mp.state.selected_voice .. "_rule_application", x-4)
        end
      end
    end

    --
    --  time mode
    --
    if mp.focus == "TIME" then

    end

    --
    --  config mode
    --
    if mp.focus == "CONFIG" then

    end

    --
    --  alt mode
    --
    if mp.focus == "ALT" then

    end
    redraw()
    mp_grid:draw(mp)
  end


  function mp:draw()
    mp_ui:draw(mp)
  end

  function mp:gridredraw()
    mp_grid:draw(mp)
  end

  return mp

end


return Meadowphysics
