--[[------------------------------------------------------------------------------------

  Play / Panic Stop
  
  simple command allows to assing play and panic stop (full sound stop) to a key
  or midi controller. This is usefull to stop all sounds immediately, so that
  reverb tails etc. are not hearable after pressing stop.
  
  Hint:
  this command can cause crackling etc.

  Copyright 2011 Matthias Ehrmann, 
  
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License. 
  You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0 
  
  Unless required by applicable law or agreed to in writing, software distributed 
  under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR 
  CONDITIONS OF ANY KIND, either express or implied. See the License for the specific 
  language governing permissions and limitations under the License. 
  
-------------------------------------------------------------------------------------]]--


--[[ initialize ]] --------------------------------------------------------------


renoise.tool():add_keybinding {
  name = "Global:Transport:Play/Panic Stop",
  invoke = function() play_panic_stop_hard() end
}
 
renoise.tool():add_midi_mapping {
  name = "Global:Transport:Play/Panic Stop",
  invoke = function() play_panic_stop_hard() end
}

function play_panic_stop_hard()

  if (renoise.song().transport.playing) then
    renoise.song().transport:panic()
  else
    local start_mode = renoise.Transport.PLAYMODE_RESTART_PATTERN
    renoise.song().transport:start(start_mode)  
  end
end

function play_panic_stop_ramped()

  
  if (renoise.song().transport.playing) then
  
    -- Add a new timer for ramping down/up
    if (not renoise.tool():has_timer(ramp_down())) then
      renoise.tool():add_timer(ramp_down(),500)
    end
  
    --local tracks = renoise.song().tracks
    --for t = 1,#tracks do
    --  if (tracks[t].type == renoise.Track.TRACK_TYPE_MASTER) then
    --    renoise.song().tracks[t].postfx_volume.value = 0.0
    --  end
    --end

    --renoise.song().transport:panic()
  else

    local tracks = renoise.song().tracks
    for t = 1,#tracks do
      if (tracks[t].type == renoise.Track.TRACK_TYPE_MASTER) then
        renoise.song().tracks[t].postfx_volume.value = math.db2lin(0)
      end
    end
  
    local start_mode = renoise.Transport.PLAYMODE_RESTART_PATTERN
    renoise.song().transport:start(start_mode)  
  end
end

function ramp_down()
  --for t = 1,#renoise.song().tracks do
  print("start")
  --  if (renoise.song().tracks[t].type == renoise.Track.TRACK_TYPE_MASTER) then
  --    local current_value = renoise.song().tracks[t].postfx_volume.value - math.db2lin(10)           
  --    if (current_value < 0.0) then
  --      current_value = 0.0
        renoise.tool():remove_timer(ramp_down())
  --    end
  --    print(current_value) 
  --    renoise.song().tracks[t].postfx_volume.value = current_value
  --    return;
  --  end
  --end      
end

--[[ debug ]]--------------------------------------------------------------]]--

_AUTO_RELOAD_DEBUG = true
