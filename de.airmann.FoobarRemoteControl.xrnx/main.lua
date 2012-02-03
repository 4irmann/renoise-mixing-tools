--[[----------------------------------------------------------------------------

  Foobar 20000 Remote Control (over http)
  
  Provides Renoise commands for controlling foobar2000 media player over http
  (local or remote network) from inside Renoise. This can be helpfull for 
  doing A/B comparisons/referencing against commercial tunes from inside Renoise. 
  
  Supported commands are: start, stop, play, pause. Those commands can be
  assigned to keyboard shortcuts or midi controllers.  
  
  In order to use this tool, the foobar 2000 "httpd_control" plugin must be 
  installed and properly  configured (listen e.g. on localhost:8888). Moreover, 
  you have to create a "renoise" httpd_control theme (sub dir) in httpd_control 
  home directory. Attention when running on localhost: Renoise soundcard 
  samplerate must be the same as in foobar2000, otherwise foobar probably won't play. 
  
  Hints: 
  
  of course, alternatively to this "solution" you could also use Foobar 
  "global" Keyboard shortcuts. But in this case you can't control it
  using a midi controller, and you can't control a foobar2000 instance which
  is running somewhere else in the web than on 127.0.0.1 = localhost.
  
  I recommend to use the foobar "console" for debugging, and add the extensions 
  "waveform seeking" and "foo_seek" to foobar. Waveform seek is similar
  to soundcloud waveform display. With foo_seek A/B looping in songs is possible. 
  
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

require "Helpers"


-- default preferences
local prefs = renoise.Document.create("FoobarRemoteControlPreferences") { 

    -- IP address and port number of foobar httpd control server
    foobar_http_control_server = "127.0.0.1",    
    foobar_http_control_server_port = 8888,
    
    -- client connection and receive timeout in milliseconds
    connection_timeout = 2000,
    receive_timeout = 500,
    
    -- Xfade default Type, either:
    -- dipped
    -- intermediate
    -- const_power
    -- slow_fade
    -- slow_cut
    -- fast_cut
    -- transition
    xfade_default_type = "fast_cut",
    
    -- link foobar volume and xfade volume
    linked_volumes = true
}

-- data structure for virtual device parameters
class "VirtualDeviceParameter"(renoise.Document.DocumentNode)

function VirtualDeviceParameter:__init()

  -- important! call super first
  renoise.Document.DocumentNode.__init(self)
  
  self.name = "n/a"
  self.polarity = renoise.DeviceParameter.POLARITY_UNIPOLAR
  self.value_min = 0.0
  self.value_max = 1.0
  self.value_quantum = 0.5
  self.value_default = 1.0
  self.value = 0.0
end

-- stores foobar volume 
local fb2k_volume = VirtualDeviceParameter()
fb2k_volume.name = "fb2k_foobar_volume"
fb2k_volume.value_default = 1.0
fb2k_volume.value = 1.0

-- stores foobar xfade volume
local fb2k_xfade_volume = VirtualDeviceParameter()
fb2k_xfade_volume.name = "fb2k_foobar_xfade_volume"
fb2k_xfade_volume.value_default = 0.0
fb2k_xfade_volume.value = 0.0

-- stores foobar playing position
local fb2k_position = VirtualDeviceParameter()
fb2k_position.name = "fb2k_foobar_position"

-- stores xfade position
-- 0 = only Renoise
-- 1.0 = only foobar
local fb2k_xfade_position = VirtualDeviceParameter() 
fb2k_xfade_position.name = "fb2k_xfade_pos"
fb2k_xfade_position.value_default = 1.0
fb2k_xfade_position.value = 1.0
           
if (io.exists("config.xml")) then
  prefs:load_from("config.xml")
else
  prefs:save_as("config.xml") -- just for initial generation
end

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
  name = "Global:Tools:FB2K Stop [Trigger]",
  invoke = function() fb2k_stop() end 
}
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2K Stop",
  invoke =  function(message)
              if (message:is_trigger()) then
                fb2k_stop() 
              end
            end  
}

-- Play/Pause
renoise.tool():add_keybinding {
  name = "Global:Tools:FB2K PlayOrPause",
  invoke = function() fb2k_play_or_pause() end
}
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2K PlayOrPause [Trigger]",
  invoke =  function(message) 
              if (message:is_trigger()) then
                fb2k_play_or_pause() 
              end
            end  
}

-- Next
renoise.tool():add_keybinding {
  name = "Global:Tools:FB2K StartNext",
  invoke = function() fb2k_start_next() end
}
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2K StartNext [Trigger]",
  invoke =  function(message) 
              if (message:is_trigger()) then
                fb2k_start_next() 
              end
            end  
}

-- Previous
renoise.tool():add_keybinding {
  name = "Global:Tools:FB2K StartPrevious",
  invoke = function() fb2k_start_previous() end
}
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2K StartPrevious [Trigger]",
  invoke =  function(message) 
              if (message:is_trigger()) then
                fb2k_start_previous() 
              end
            end  
}

-- Volume (so far just midi)
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2K SetVolume [Set]",
  invoke =  function(message)               
              fb2k_volume.value = parameter_message_value(message,fb2k_volume)              
              if (prefs.linked_volumes.value == true) then
                fb2k_set_volume_db(fb2k_linked_volume_value())
              else
                fb2k_set_volume_db(fb2k_volume.value)
              end                
            end            
}

-- Seek (so far just midi)
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2K SeekTo [Set]",
  invoke =  function(message)               
              fb2k_position.value = parameter_message_value(message,fb2k_position)                           
              fb2k_seek_to(fb2k_position) 
            end            
}

--- XFade Renoise-Foobar (so far just midi)
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2K XFadeRenoiseFB2K [Set]",
  invoke =  function(message)                 
              fb2k_xfade_position.value = parameter_message_value(message,fb2k_xfade_position)              
              fb2k_xfade(fb2k_xfade_position) 
            end            
}

-- simple rounding function, precision: nr of decimal places
-- return int value
function round(value,decimalPlaces)
  return math.floor(value*10^decimalPlaces+0.5)/10^decimalPlaces 
end

function fb2k_xfade_dipped(x)
  return 1.0-x^2
end

function fb2k_xfade_intermediate(x)
  return 1.0-x
end

-- constant power xfade
-- provides constant power (n=0), slow fade (n=1), slow cut (n=3), fast cut (n=10)
-- See http://math.stackexchange.com/questions/4621/simple-formula-for-curve-of-dj-crossfader-volume-dipped
-- x: 0.0 .. 1.0 
-- y: 0.0 .. 1.0
function fb2k_xfade_const_power(x,n)   
  return math.cos(math.pi*0.25*(((2*x-1)^(2*n+1)+1)))
end

function fb2k_xfade_transition(x) 
    local y =2.0*(1.0-x)
    if y >= 1.0 then y = 1.0 end
    return y
end

-- XFade
function fb2k_xfade(devPara,xfade_type)

  print("XFade Pos: "..(devPara.value*100))
  local x = devPara.value
  local n = 0 
  local xfade_func
  
  if (xfade_type == nil) then
    xfade_type = prefs.xfade_default_type.value
  end  
  
  if (xfade_type == "dipped") then
    xfade_func = fb2k_xfade_dipped  
  
  elseif (xfade_type == "intermediate") then
    xfade_func = fb2k_xfade_intermediate
    
  elseif (xfade_type == "const_power") then
    n = 0
    xfade_func = fb2k_xfade_const_power
  
  elseif (xfade_type == "slow_fade") then
    n = 1
    xfade_func = fb2k_xfade_const_power  
    
  elseif (xfade_type == "slow_cut") then
    n = 3
    xfade_func = fb2k_xfade_const_power  
  
  elseif (xfade_type == "fast_cut") then
    n = 10
    xfade_func = fb2k_xfade_const_power  
  
  elseif (xfade_type == "transition") then
    xfade_func = fb2k_xfade_transition
  
  end
      
  local renoise_vol = xfade_func(x,n)
  print("REN VOL: "..renoise_vol)  
  master_track().postfx_volume.value = renoise_vol
  
   
  fb2k_xfade_volume.value = xfade_func(1.0-x,n)   
  local foobar_vol
  if (prefs.linked_volumes.value == true) then
    foobar_vol = fb2k_linked_volume_value()    
  else
    foobar_vol = fb2k_xfade_volume.value
  end    
  print("FOO VOL: "..foobar_vol)
  fb2k_set_volume_db(foobar_vol)
end

-- Start
function fb2k_start(param1)
  fb2k_cmd("Start",param1)
end

-- Stop
function fb2k_stop(param1)
  fb2k_cmd("Stop",param1)
end

-- Play/Pause
function fb2k_play_or_pause(param1)
  fb2k_cmd("PlayOrPause",param1)
end

-- StartNext
function fb2k_start_next(param1)
  fb2k_cmd("StartNext", param1)
end

-- StartPrevious
function fb2k_start_previous(param1)
  fb2k_cmd("StartPrevious", param1)
end

-- Linked foobar / xfade volume
function fb2k_linked_volume_value()
  return fb2k_volume.value * fb2k_xfade_volume.value
end

-- actually we don't need it, since set_volume_db is more precise
-- Volume : linear (0.0..1.0 float) f1()->  linear (0..100 uint) f(2)-> log  (-100..0 dB float)
--function fb2k_set_volume(devPara)   
--  local value = math.floor(devPara.value*100+0.5)
--  fb2k_cmd("Volume",value)
--  print("FOO VOL: "..value)
--end   

-- VolumeDB : linear (0.0..1.0 float) f1()-> log (1000..0 uint) f(2)-> log (-100..0 dB float)
function fb2k_set_volume_db(value)   
  local foobar_value = math.floor(math.lin2db(value)*-10+0.5)  
  
  -- Renoise volume range <= 0 dB: from -200 dB .. +0 dB -> 10^-10 .. 1.0
  -- foobar  volume range <= 0 dB: from -100 dB .. +0 dB -> 10^-5 .. 1.0 -> 1000 .. 0
  if (foobar_value > 1000) then 
    foobar_value = 1000
  end  
  
  print("FOO VOL DB: "..foobar_value)
  fb2k_cmd("VolumeDB",foobar_value)  
end   

-- Seek : linear (0.0..1.0 float) f1() -> (0..100 uint)
function fb2k_seek_to(devPara)  
  local value = math.floor(devPara.value*100+0.5)
  fb2k_cmd("Seek",value)
  print("FOO SEEK:"..value)
end
  
-- HTTP / GET client
-- create a TCP socket and connect it e.g. to localhost:8888 http (= foobar
-- http_control), giving up the connection attempt after 2 seconds
function fb2k_cmd(cmd,param1)

  local connection_timeout = prefs.connection_timeout.value
  local http_server = prefs.foobar_http_control_server.value
  local http_server_port = prefs.foobar_http_control_server_port.value
    
  local client, socket_error = 
    renoise.Socket.create_client(http_server, 
      http_server_port,renoise.Socket.PROTOCOL_TCP, connection_timeout)
   
  if socket_error then 
    renoise.app():show_warning(socket_error)
    return
  end

  -- Send foobar command as HTTP request
  local message = "GET /renoise/?cmd="..cmd
  if (param1 ~= nil) then
    message = message.."&param1="..param1
  end
  message = message.." HTTP/1.0\r\nHost: "..http_server.."\r\n\r\n"
  
  local succeeded, socket_error = client:send(message)
  if (socket_error) then 
    renoise.app():show_warning(socket_error)
    return
  end

  -- loop until we get no more data from the server. 
  -- note: this is a silly example. we should check the HTTP 
  -- header here and stop after receiveing "Content-Length"
  local receive_succeeded = false
  local receive_content = ""

  while (true) do
    local receive_timeout = prefs.receive_timeout.value
  
    local message, socket_error = 
      client:receive("*line", receive_timeout)
    
    if (message) then 
      receive_content = receive_content..message.."\n"
  
    else
      if (socket_error == "timeout" or 
          socket_error == "disconnected") 
      then
        -- could retry here on timeout. we just stop...
        receive_succeeded = true
        break
      else
        renoise.app():show_warning(
          "'socket reveive' failed with the error: "..socket_error)
        break
      end
    end
  end
 
  -- close the connection if it was not closed by the server
  if (client and client.is_open) then
    client:close()
  end

  -- show what we've got
  if (receive_succeeded and #receive_content > 0) then
    -- just for debugging
    --renoise.app():show_prompt(
    --  "GET / HTTP/1.0 response", 
    --    receive_content, 
    --      {"OK"}
  --)
  else
    renoise.app():show_prompt(
      "GET / HTTP/1.0 response", 
        "Socketreceive timeout.", 
          {"OK"}
  ) 
  end

end

--[[ debug ]]---------------------------------------------------------------]]--

_AUTO_RELOAD_DEBUG = true
