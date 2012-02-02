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
    
    -- Xfade Type
    -- 0 = Constant Power (n=0)
    -- 1 = Constant Power Slow Fade (n=1)
    -- 3 = Constant Power Slow Cut (n=3)
    -- 10 = Constant Power Fast Cut (n=10)
    xfade_type = 0
}

-- data structure for virtual device parameters
class "VirtualDeviceParameter"(renoise.Document.DocumentNode)

function VirtualDeviceParameter:__init()

  -- important! call super first
  renoise.Document.DocumentNode.__init(self)
  
  self.name = "n/a"
  self.polarity = renoise.DeviceParameter.POLARITY_UNIPOLAR
  self.value_min = 0
  self.value_max = 127
  self.value_quantum = 0.5
  self.value_default = 127
  self.value = 0    
end

-- stores foobar volume (0..100)
local fb2k_volume = VirtualDeviceParameter()
fb2k_volume.name = "fb2k_foobar_volume"
fb2k_volume.value_min = 0
fb2k_volume.value_max = 100
fb2k_volume.value = 100

-- stores foobar playing position (0..100)
local fb2k_position = VirtualDeviceParameter()
fb2k_position.name = "fb2k_foobar_position"
fb2k_position.value_min = 0
fb2k_position.value_max = 100
fb2k_position.value = 0

-- stores xfade position (7bit 0..127)
-- 0 = only Renoise
-- 127 = only foobar
local fb2k_xfade_position = VirtualDeviceParameter() 
fb2k_xfade_position.name = "fb2k_xfade_pos"
fb2k_xfade_position.value = 127
              

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
  name = "Global:Tools:FB2k Start [Trigger]",
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
  name = "Global:Tools:FB2k Stop",
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
  name = "Global:Tools:FB2k PlayOrPause [Trigger]",
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
  name = "Global:Tools:FB2k StartNext [Trigger]",
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
  name = "Global:Tools:FB2k StartPrevious [Trigger]",
  invoke =  function(message) 
              if (message:is_trigger()) then
                fb2k_start_previous() 
              end
            end  
}

-- Volume (so far just midi)
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2k SetVolume [Set]",
  invoke =  function(message)               
              fb2k_volume.value = parameter_message_value(message,fb2k_volume)              
              fb2k_set_volume(fb2k_volume)
            end            
}

-- Seek (so far just midi)
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2k SeekTo [Set]",
  invoke =  function(message)               
              fb2k_position.value = parameter_message_value(message,fb2k_position)                           
              fb2k_seek_to(fb2k_position) 
            end            
}

--- XFade Renoise-Foobar (so far just midi)
renoise.tool():add_midi_mapping {
  name = "Global:Tools:FB2k XFadeRenoiseFB2K [Set]",
  invoke =  function(message)                 
              fb2k_xfade_position.value = parameter_message_value(message,fb2k_xfade_position)              
              fb2k_xfade(fb2k_xfade_position) 
            end            
}

-- precision: nr of decimal places
function round(value,decimalPlaces)
  return math.floor(value*10^decimalPlaces+0.5)/10^decimalPlaces 
end

--  Constant Power XFade
-- See http://math.stackexchange.com/questions/4621/simple-formula-for-curve-of-dj-crossfader-volume-dipped
-- x: 0.0 - 1.0 
-- y: 0.0 - 1.0
function fb2k_const_pow_xfade(x,n)   
  return math.cos(math.pi*0.25*(((2*x-1)^(2*n+1)+1)))
end

-- XFade
function fb2k_xfade(devPara)

  print("XFade Pos: "..devPara.value)
  local x = devPara.value / devPara.value_max
  local n = prefs.xfade_type.value
  
  local renoise_vol = fb2k_const_pow_xfade(x,n) 
  master_track().postfx_volume.value = renoise_vol
  print("REN VOL: "..renoise_vol)
    
  fb2k_volume.value = 
    fb2k_const_pow_xfade(1.0-x,n)*fb2k_volume.value_max
  fb2k_set_volume(fb2k_volume)  
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

-- Volume 
function fb2k_set_volume(devPara)  
  local value = math.floor(devPara.value+devPara.value_quantum)
  fb2k_cmd("Volume",value)
  print("FOO VOL: "..value)
end

-- Seek 
function fb2k_seek_to(devPara)
  local value = math.floor(devPara.value+devPara.value_quantum)
  fb2k_cmd("Seek",value)
end
  
-- HTTP / GET client
-- create a TCP socket and connect it e.g. to localhost:8888 http (= foobar
-- http_control), giving up the connection attempt after 2 seconds
function fb2k_cmd(cmd,param1)

  local connection_timeout = prefs.connection_timeout.value
  local http_server = prefs.foobar_http_control_server.value
  local http_server_port = prefs.foobar_http_control_server_port.value
    
  local client, socket_error = renoise.Socket.create_client(http_server, http_server_port,renoise.Socket.PROTOCOL_TCP, connection_timeout)
   
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
