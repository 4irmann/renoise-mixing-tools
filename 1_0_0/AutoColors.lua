 --[[------------------------------------------------------------------------------------
  
  AutoColors
  
  Automatically sets track colors by track names, using regular expression filters.
  E.g. you can assign a filter "*hat*" to a RGB color value. All track names which
  contain a "hat" string will have the same color.
  
  Copyright 2012 Matthias Ehrmann, 
  
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License. 
  You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0 

  Unless required by applicable law or agreed to in writing, software distributed 
  under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR 
  CONDITIONS OF ANY KIND, either express or implied. See the License for the specific 
  language governing permissions and limitations under the License.  
--------------------------------------------------------------------------------------]]--

-- data structure for color map entries
class "AutoColorMapEntry"(renoise.Document.DocumentNode)

function AutoColorMapEntry:__init()

  -- important! call super first
  renoise.Document.DocumentNode.__init(self)

  self:add_properties {
    filters = { "" },
    color = {0xff,0xff,0xff},
    color_blend = 20
  }
  
end


-- main class 
class "AutoColors"

-- includes and outsourced stuff
require "Debug"
require "Helpers"

-- constructor for initializations on application level 
-- nothing song specific is initialized in here
function AutoColors:__init()

  TRACE("__init()")

  -- member variables
  
  self.found = false -- flag that indicates that e.g. a filter could be found
  self.config_path = "config.xml" 
 
  -- preferences 
  
  self.prefs = renoise.Document.create("AutoColorPreferences") {          
    color_map = renoise.Document.DocumentList()
  }    
  --self.prefs.color_map:insert(renoise.Document.create("AutoColorMapEntry") {
  --  filters = {""}, color= {0xff,0xff,0xff}, color_blend = 20 
  --})
  
  --self.prefs:save_as(self.config_path)   
  self.prefs:load_from(self.config_path)  

  -- tool registration  
  
  renoise.tool():add_menu_entry {
    name = "Main Menu:View:AutoColors Filters",
    invoke = function() self:toggle_filter_dialog() end,
    selected = function() return self:filter_dialog_visible() end
  }

  renoise.tool():add_keybinding {
    name = "Global:Tools:Show AutoColor Filters",
    invoke = function() self:toggle_filter_dialog() end,
    selected = function() return self:filter_dialog_visible() end
  }  

  renoise.tool():add_midi_mapping {
    name = "Global:Tools:Show AutoColor Filters",
    invoke = function() self:toggle_filter_dialog() end,
    selected = function() return self:filter_dialog_visible() end
  }  
    
  -- add new song observer
  if (not renoise.tool().app_new_document_observable:has_notifier(
    self,self.on_song_created)) then
    renoise.tool().app_new_document_observable:add_notifier(
      self,self.on_song_created)
  end
  
   -- add song pre-release observer  
  if (not renoise.tool().app_release_document_observable:has_notifier(
    self,self.on_song_pre_release)) then
    renoise.tool().app_release_document_observable:add_notifier(
      self,self.on_song_pre_release)
  end
       
  -- dialogs 'n views
  local vb = renoise.ViewBuilder()
  self.filter_dialog = nil
  local filter_dialog_width = 350
  
  self.filter_list = 
    vb:multiline_textfield {
        text = "",
        width = filter_dialog_width,
        height = 500,        
    }      
    
  self.filter_view = 
    vb:column {
      margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
      spacing = renoise.ViewBuilder.DEFAULT_DIALOG_SPACING,
      self.filter_list
    }
  self:update_filter_view()
  
  if (not self.prefs.color_map:has_notifier(
    self,self.on_update_filter_list)) then
    self.prefs.color_map:add_notifier(
      self,self.on_update_filter_list)
  end
end

function AutoColors:add_track_name_changed_notifier(track)

  TRACE("add_track_name_changed_notifier()")

  if (not track.name_observable:has_notifier(
    self,self.on_track_name_changed)) then
    track.name_observable:add_notifier(
      self,self.on_track_name_changed)               
  end
end

function AutoColors:remove_track_name_changed_notifier(track)

  TRACE("remove_track_name_changed_notifier()")
 
  if (track.name_observable:has_notifier(
    self,self.on_track_name_changed)) then
    track.name_observable:remove_notifier(
      self,self.on_track_name_changed) 
  end
end

-- song created handler
-- reset member variables and register notifiers
function AutoColors:on_song_created()
  
  TRACE("on_song_created()")
  
  if (not song().tracks_observable:has_notifier(
    self,self.on_tracks_changed)) then
    song().tracks_observable:add_notifier(
      self,self.on_tracks_changed)
  end
    
  for t = 1,#song().tracks do          
    self:on_tracks_changed({type = "insert", index = t})    
  end
  
end

-- song pre release handler
-- this is called right before the song is being released
function AutoColors:on_song_pre_release()

  TRACE("on_song_pre_release()")    
  
  -- TODO free listeners ? Guess this is automatically done by Renoise    
end

function AutoColors:on_tracks_changed(notification)

  TRACE("on_tracks_changed()")

  if (notification.type == "insert") then
    self:add_track_name_changed_notifier(song().tracks[notification.index])  
    
    -- force "has changed"
    self:on_track_name_changed()
  
  elseif (notification.type == "remove") then  
    self:remove_track_name_changed_notifier(song().tracks[notification.index])
    
    -- force "has changed"
    self:on_track_name_changed()        
  end  
end
  
function AutoColors:on_track_name_changed() 
  
  TRACE("on_track_name_changed()")
  
  self.found = false      
  
  -- since we don't know the source track index
  -- we have to iterate over all tracks.
  -- This is not nice, but there's no better solution
  for t = 1,#song().tracks do      
   
    local name = song().tracks[t].name
     
    ------------------------------------------------------------
    -- handle commands
    -- these commands modify the filters / color mapping list
     
    -- add filter
    if (name:find("^add:.*$")) then
   
      local name = string.sub(name,5)     
      if (self:find_filter(name)) then
        
        self:print_feedback_msg(song().tracks[t], "EXISTS")
        return 
      end
        
      self:add_filter(song().tracks[t], name)        
      self:apply_filters()
      return 
      
    -- remove filter
    elseif (name:find("^rem:.*$")) then
    
      -- iterate over all tracks and
      -- remove ALL matching filters
      local name = string.sub(name,5) 
      for u = 1,#song().tracks do
        self:remove_filter(song().tracks[u], name)        
      end
      
      -- switch notification temporarily off to avoid feedback loop      
      self:remove_track_name_changed_notifier(song().tracks[t])
      
      if (self.found) then
        self:print_feedback_msg(song().tracks[t],"REMOVED")
      else
        self:print_feedback_msg(song().tracks[t],"NOT FOUND")
      end
      
      -- switch notification on again      
      self:add_track_name_changed_notifier(song().tracks[t])
      
      return -- just exit for-loop, don't apply filters
      
    -- update filter
    elseif (name:find("upd:.*$")) then
    
      somg().tracks[t].name = string.sub(name,5) 
      self:update_filter(song().tracks[t], name)          
      self:apply_filters()
      return
    end
  end    
    
  -- no command found: just apply filters
  self:apply_filters()  
end

function AutoColors:print_feedback_msg(track,message)

  TRACE("print_feedback_msg()")

  -- switch notification temporarily off to avoid feedback loop      
  self:remove_track_name_changed_notifier(track)  
  
  track.name = message 
  
  -- switch notification on again      
  self:add_track_name_changed_notifier(track)
end

-- iterate over all tracks/trackanmes an apply filters
function AutoColors:apply_filters()

  TRACE("apply_filters()")
  
  for t = 1,#song().tracks do        
    for i = 1,#self.prefs.color_map do
      for j = 1,#self.prefs.color_map[i].filters do
        local pattern = (self.prefs.color_map[i].filters[j].value)
        if (song().tracks[t].name:find(pattern)) then     
          song().tracks[t].color = 
            { self.prefs.color_map[i].color[1].value, 
              self.prefs.color_map[i].color[2].value, 
                self.prefs.color_map[i].color[3].value}
          song().tracks[t].color_blend = self.prefs.color_map[i].color_blend.value         
        end   
      end   
    end
  end
end

-- searches for a specific filter pattern in the filter / colormap list
-- returns true if found, otherwise false
function AutoColors:find_filter(filter)

  TRACE("find_filter()")
  
  for i = 1,#self.prefs.color_map do
    for j = 1,#self.prefs.color_map[i].filters do
      local pattern = (self.prefs.color_map[i].filters[j].value)
      if (filter == pattern) then     
          return true;
      end   
    end
  end
    
  return false;
end
  
function AutoColors:add_filter(track,filter)   

  TRACE("add_filter()")
          
  -- update prefs
  self.prefs.color_map:insert(renoise.Document.create("AutoColorMapEntry") {
    filters = { filter }, color = track.color, color_blend = track.color_blend
  })
  self.prefs:save_as(self.config_path)

  -- switch notification temporarily off to avoid feedback loop      
  self:remove_track_name_changed_notifier(track)
      
  track.name = filter

  -- switch notification on again      
  self:add_track_name_changed_notifier(track)
end

function AutoColors:update_filter(track,filter_pattern)   

  TRACE("update_filter()")  
  
  -- TODO  
end

function AutoColors:remove_filter(track,filter)   

  TRACE("remove_filter()")
        
  for i = 1,#self.prefs.color_map do
    for j = 1,#self.prefs.color_map[i].filters do
      if (filter == self.prefs.color_map[i].filters[j].value) then
        self.prefs.color_map:remove(i)
        self.prefs:save_as(self.config_path)-- update prefs
        self.found = true
        return
      end
    end
  end
end

-- filter dialog handler
function AutoColors:toggle_filter_dialog()
  if (self:filter_dialog_visible()) then
    self.filter_dialog:close()
  else
    if (self.filter_view) then
      self:update_filter_view()
      self.filter_dialog = 
        renoise.app():show_custom_dialog("AutoColors Filters", self.filter_view)  
    end
  end
end

-- indicates if filter dialog is visible/valid
function AutoColors:filter_dialog_visible()

  TRACE("filter_dialog_visible()")

  return self.filter_dialog and self.filter_dialog.visible
end

function AutoColors:on_update_filter_list()

  TRACE("on_update_filter_list()")
  
  if (self:filter_dialog_visible()) then
    self:update_filter_view()
  end
end

-- updates datat/text of filter view (child views)
function AutoColors:update_filter_view()
  
  TRACE("update_filter_view()")
  
  self.filter_list.text = "[ R, G, B ]   [BLEND %] <- FILTERS\n"..
                          "````````````````````````````````````````````````````````````````````\n"
  
  if (#self.prefs.color_map <= 0) then
    self.filter_list.text = self.filter_list.text..">> NO FILTERS DEFINED ! <<\n"    
  else
    for i = 1,#self.prefs.color_map do
    
      local cm = self.prefs.color_map[i]
    
      self.filter_list.text = self.filter_list.text..
        string.format("%s%X,%X,%X%s%d%s ",
          "[",cm.color[1].value,cm.color[2].value,cm.color[3].value,"]   [", 
            cm.color_blend.value,"%] <- ")
              
      for j = 1,#self.prefs.color_map[i].filters do        
          self.filter_list.text = self.filter_list.text..cm.filters[j].value.." "
      end
      self.filter_list.text = self.filter_list.text.."\n"
    end    
  end
  
  local help = "\nCOMMANDS - enter them in any track's name input field:\n".. 
               "````````````````````````````````````````````````````````````````````\n"..              
               "add:<regex>    add a new simple text filter or regex\n"..
               "upd:<regex>    update an already present filter\n"..
               "rem:<regex>    remove filter\n"..
               "res:                     reset = remove all filters\n"..
               "lst:                      show this dialog\n\n"..
               
               "REGULAR EXPRESSIONS:\n"..
               "````````````````````````````````````````````````````````````````````\n"..
               "CHARS:    ^ start     $ end    . any     ? 0..1      * 0..n      + 1..n\n".. 
               "                   %l/u% lcase/ucase     %d digit      %d2 two digits\n"..
               " SETS:   [123] any    [a-z] range    [^123] neg set\n\n"..               
               
               "````````````````````````````````````````````````````````````````````\n"..
               "EXAMPLES:\n\n"..  
               "snare     ^kick[123]$      drum*     synth.+  \n\n"..
               "More info:  http://lua-users.org/wiki/PatternsTutorial\n\n"..
               "(c) 2012, Airmann Productions"
    
  self.filter_list.text = self.filter_list.text..help
end  

  
  
