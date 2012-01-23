--[[----------------------------------------------------------------------------

  Foobar 20000 Remote Control
  
  Provides Renoise commands for controlling foobar2000 media player over http
  (local or remote network) from inside Renoise. This can be helpfull for 
  doing A/B comparisons/referencing against commercial tunes from inside Renoise. 
  
  Supported commands are: start, stop, play, pause. Those commands can be
  assigned to keyboard shortcuts or midi controllers.  
  
  In order to use this tool, the foobar 2000 "httpd_control" plugin must be 
  installed and properly  configured (listen e.g. on localhost:8888). Moreover, 
  you have to create a  "renoise" httpd_control theme (sub dir) in httpd_control 
  home directory. Attention: Renoise soundcard samplerate must be the same as 
  in foobar2000, otherwise foobar probably won't play. 
  
  Hints: 
  
  of course, alternatively to this "solution" you could also use Foobar 
  "global" Keyboard shortcuts. But in this case you can't control it
  using a midi controller.
  
  use the foobar "console" for debugging, and add the extensions 
  "waveform seeking" and "foo_seek" to foobar. Waveform seek is similar
  to soundcloud. With foo_seek A/B looping in songs is possible. 
  
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


renoise.tool():add_keybinding {
  name = "Global:Transport:FB2K Start",
  invoke = function() fb2k_start() end
}

renoise.tool():add_keybinding {
  name = "Global:Transport:FB2K Stop",
  invoke = function() fb2k_stop() end
}

renoise.tool():add_keybinding {
  name = "Global:Transport:FB2K PlayOrPause",
  invoke = function() fb2k_play_or_pause() end
}

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

function fb2k_cmd(cmd,param1)

-- HTTP / GET client

-- create a TCP socket and connect it to localhost:8888 http (= foobar
-- http_control), giving up the connection attempt after 2 seconds

  local connection_timeout = 2000
    
  local client, socket_error = renoise.Socket.create_client(
    "127.0.0.1", 8888, renoise.Socket.PROTOCOL_TCP, connection_timeout)
   
  if socket_error then 
    renoise.app():show_warning(socket_error)
    return
  end

  -- Send foobar command as HTTP request
  local message = "GET /renoise/?cmd="..cmd.." HTTP/1.0\r\nHost: 127.0.0.1\r\n\r\n"
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
    local receive_timeout = 500
  
    local message, socket_error = 
      client:receive("*line", receive_timeout)
    
    if (message) then 
      receive_content = receive_content .. message .. "\n"
  
    else
      if (socket_error == "timeout" or 
          socket_error == "disconnected") 
      then
        -- could retry here on timeout. we just stop...
        receive_succeeded = true
        break
      else
        renoise.app():show_warning(
          "'socket reveive' failed with the error: " .. socket_error)
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
    --renoise.app():show_prompt(
    --"GET / HTTP/1.0 response", 
    --receive_content, 
    --{"OK"}
  --)
  else
    renoise.app():show_prompt(
    "GET / HTTP/1.0 response", 
    "Socket receive timeout.", 
    {"OK"}
  ) 
  end

end

--[[ debug ]]---------------------------------------------------------------]]--

_AUTO_RELOAD_DEBUG = true
