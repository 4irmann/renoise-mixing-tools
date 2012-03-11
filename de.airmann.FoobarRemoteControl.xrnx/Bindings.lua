--[[----------------------------------------------------------------------------

  Foobar 20000 Remote Control (over http)  
  
  Copyright 2011 Matthias Ehrmann, 
  
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License. 
  You may obtain a copy of the License at 
  http://www.apache.org/licenses/LICENSE-2.0 
  
  Unless required by applicable law or agreed to in writing, software 
  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT 
  WARRANTIES ORCONDITIONS OF ANY KIND, either express or implied. See the 
  License for the specific language governing permissions and limitations 
  under the License. 
   
----------------------------------------------------------------------------]]--

-- launch foobar2000
renoise.tool():add_keybinding {
  name = "Global:Tools:FB2K Launch Foobar2000",
  invoke = function() fb2k_launch() end
}
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2K Launch Foobar2000 [Trigger]",
  invoke =  function(message)
              if (message:is_trigger()) then
                fb2k_launch()
              end
            end
}           

-- Start
renoise.tool():add_keybinding {
  name = "Global:Tools:FB2K Start",
  invoke = function() fb2k_start() end
}
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2K Start [Trigger]",
  invoke =  function(message) 
              if (message:is_trigger()) then
                fb2k_start() 
              end
            end
}

-- Stop
renoise.tool():add_keybinding {
  name = "Global:Tools:FB2K Stop",
  invoke = function() fb2k_stop() end 
}
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2K Stop [Trigger]",
  invoke =  function(message)
              if (message:is_trigger()) then
                fb2k_stop() 
              end
            end  
}

-- Play/Pause
renoise.tool():add_keybinding {
  name = "Global:Tools:FB2K Play Or Pause",
  invoke = function() fb2k_play_or_pause() end
}
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2K Play Or Pause [Trigger]",
  invoke =  function(message) 
              if (message:is_trigger()) then
                fb2k_play_or_pause() 
              end
            end  
}

-- Next
renoise.tool():add_keybinding {
  name = "Global:Tools:FB2K Start Next",
  invoke = function() fb2k_start_next() end
}
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2K Start Next [Trigger]",
  invoke =  function(message) 
              if (message:is_trigger()) then
                fb2k_start_next() 
              end
            end  
}

-- Previous
renoise.tool():add_keybinding {
  name = "Global:Tools:FB2K Start Previous",
  invoke = function() fb2k_start_previous() end
}
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2K Start Previous [Trigger]",
  invoke =  function(message) 
              if (message:is_trigger()) then
                fb2k_start_previous() 
              end
            end  
}

-- Volume (pure midi)
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2K Set Volume [Set]",
  invoke =  function(message)               
              fb2k_volume.value = parameter_message_value(message,fb2k_volume)                                          
              if (xfade_is_running()) then
                
                fb2k_set_volume_db(fb2k_volume.value)              
              end
            end            
}

-- Seek (pure midi)
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2K Seek To [Set]",
  invoke =  function(message)               
              fb2k_xfade_position.value =
                parameter_message_value(message,fb2k_xfade_position)                           
              fb2k_seek_to(fb2k_xfade_position) 
            end            
}

--- XFade manual (both directions: Ren->Foo, Foo->Ren)
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2K XFade Position [Set]",
  invoke =  function(message)                 
              -- TODO
              if (xfade_running) then
                -- TODO: stop auto xfade
              end
              fb2k_xfade_position.value = parameter_message_value(message,fb2k_xfade_position)              
              fb2k_xfade(fb2k_xfade_position) 
            end            
}

--- XFade auto Ren->Foo 
renoise.tool():add_keybinding {
  name = "Global:Tools:FB2K XFade Ren->FB2k",
  invoke = function() fb2k_xfade_start_auto(true) end
}
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2K XFade Ren->FB2K [Trigger]",
  invoke =  function(message)
              if (message:is_trigger()) then                 
                fb2k_xfade_start_auto(false)
              end
            end            
}

--- XFade auto Foo->Ren
renoise.tool():add_keybinding {
  name = "Global:Tools:FB2K XFade FB2k -> Ren",
  invoke = function() fb2k_xfade_start_auto(false) end
}
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2K XFade FB2K -> Ren [Trigger]",
  invoke =  function(message)
              if (message:is_trigger()) then                 
                fb2k_xfade_start_auto(true)
              end
            end            
}

--- XFade duration factor in percent (pure midi)
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2K XFade Duration Factor [Set]",
  invoke =  function(message)                 
              fb2k_xfade_duration_factor.value =
                  parameter_message_value(message,fb2k_xfade_duration_factor)                            
            end            
}
