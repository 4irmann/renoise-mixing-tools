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

require "Debug"
require "Helpers"
require "MetaXfader"

-- default preferences
prefs = renoise.Document.create("FoobarRemoteControlPreferences") { 

    foobar_app_path = "start /MIN "..renoise.tool().bundle_path..'foobar2000/foobar2000.exe',

    -- IP address and port number of foobar httpd control server
    foobar_http_control_server = "127.0.0.1",    
    foobar_http_control_server_port = 8888,
    
    -- client connection and receive timeout in milliseconds
    connection_timeout = 2000,
    receive_timeout = 500,
    
    -- Xfade default type, for all types see MetaXFader
    xfade_default_type = MetaXFader.XFADE_TYPE_CONST_POWER,
    
    -- default duration of full xfade in seconds
    xfade_default_time_duration = 60,
    
    -- scales default xfade time duration (0.0..1.0)
    xfade_default_time_duration_factor = 0.1,
    
    -- default update interval of xfade source/target in seconds
    xfade_update_interval = 0.003
}

-- data structure for virtual device parameters
-- this should be compatible with Renoise device parameter structure
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

-- foobar playing position
local fb2k_position = VirtualDeviceParameter()
fb2k_position.name = "fb2k_playing_position"

-- foobar general volume
fb2k_volume = VirtualDeviceParameter()
fb2k_volume.name = "fb2k_volume"
fb2k_volume.value_default = 1.0
fb2k_volume.value = fb2k_volume.value_default

if (io.exists("config.xml")) then
  prefs:load_from("config.xml")
else
  prefs:save_as("config.xml") -- just for initial generation
end

-- outsourced
require "Bindings"

-- Launch Foobar2000
function fb2k_launch()    
  os.execute(prefs.foobar_app_path.value)
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

-- actually we don't need it, since set_volume_db is more precise
-- Volume : linear (0.0..1.0 float) f1()->  linear (0..100 uint) f(2)-> log  (-100..0 dB float)
--function fb2k_set_volume(devPara)   
--  local value = math.floor(devPara.value*100+0.5)
--  fb2k_cmd("Volume",value)
--  print("FOO VOL: "..value)
--end   

-- TODO
function fb2k_update_volume()

  TRACE("fb2k_update_volume()")

end

-- VolumeDB : linear (0.0..1.0 float) f1()-> log (1000..0 uint) f(2)-> log (-100..0 dB float)
function fb2k_set_volume_db(value)   

  TRACE("fb2k_set_volume_db()")

  local foobar_value = math.floor(math.lin2db(value)*-10+0.5)  
  
  -- Renoise volume range <= 0 dB: from -200 dB .. +0 dB -> 10^-10 .. 1.0
  -- foobar  volume range <= 0 dB: from -100 dB .. +0 dB -> 10^-5 .. 1.0 -> 1000 .. 0
  if (foobar_value > 1000) then 
    foobar_value = 1000
  end  
  
  TRACE("FOO VOL DB: "..foobar_value)
  fb2k_cmd("VolumeDB",foobar_value)  
end   

-- Seek : linear (0.0..1.0 float) f1() -> (0..100 uint)
function fb2k_seek_to(devPara)  
  TRACE("fb2k_seek_to()")
  local value = math.floor(devPara.value*100+0.5)
  fb2k_cmd("Seek",value)
  TRACE("FOO SEEK:"..value)
end
  
-- HTTP / GET client
-- create a TCP socket and connect it e.g. to localhost:8888 http (= foobar
-- http_control), giving up the connection attempt after 2 seconds
function fb2k_cmd(cmd,param1)

  if (param1 ~= nil) then
    TRACE("fb2k_cmd("..param1..")")  
  end

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
