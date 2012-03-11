--[[----------------------------------------------------------------------------

	MetaXFader 
	
	crossfades between two device parameters A/B either automatically
	(time controlled) or manually

--------------------------------------------------------------------------------
	Foobar 2000 Remote Control (over http)

	Copyright 2012 Matthias Ehrmann,

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
require "VirtualDeviceParameter"

class "MetaXFader"

XFADE_TYPE_DIPPED = 1
XFADE_TYPE_INTERMEDIATE = 2
XFADE_TYPE_CONST_POWER = 3
XFADE_TYPE_SLOW_FADE = 4
XFADE_TYPE_SLOW_CUT = 5
XFADE_TYPE_FAST_CUT = 6
XFADE_TYPE_TRANSITION = 7

function MetaXFader:__init()

	TRACE("__init()")

	-- xfade time duration (in seconds)
	self.xfade_time_duration = VirtualDeviceParameter()
	self.xfade_time_duration.name = "xfade_time_duration"	
	self.xfade_time_duration.value_min = 0
	self.xfade_time_duration.value_max = 0xffffffff	
	self.xfade_time_duration.value_default = 60
	self.xfade_time_duration.value = xfade_time_duration_.value_default
	
	-- xfade time duration factor (0.0 .. 1.0)
	self.xfade_time_duration_factor = VirtualDeviceParameter()
	self.xfade_time_duration_factor.name = "xfade_time_duration_factor"
	self.xfade_time_duration_factor.value_default = 0.1
	self.xfade_time_duration_factor.value = xfade_time_duration_factor.value_default

	-- xfade position 0 = completely A, 1.0 = completely B
	self.xfade_position = VirtualDeviceParameter()
	self.xfade_position.name = "xfade_position"
	self.xfade_position.value_default = 0.0
	self.xfade_position.value = self.xfade_position.value_default

	-- xfade variables
	self.xfade_running = false
	self.xfade_reverse = false
	self.xfade_start_timestamp = nil
	self.xfade_last_timestamp = nil -- last call of idle function

	-- xfade type
	self.xfade_type = XFADE_TYPE_CONST_POWER
	
	-- Parameters A/B
	self.deviceParamA = nil
	self.deviceParamB = nil

	-- update functions A/B
	self.update_func_a = nil
	self.update_func_b = nil	
end

--------------------------------------------------------------------------------
-- properties setters/getters
--------------------------------------------------------------------------------

-- auto xfade running
function MetaXFader:set_auto_xfade_running(running)
	self.xfade_running = running
end
function MetaXFader:get_auto_xfade_running()
	return self.xfade_running
end

-- auto xfade reverse
function MetaXFader:set_auto_xfade_reverse(reverse)
	self.xfade_reverse = reverse
end
function MetaXFader:get_auto_xfade_reverse()
	return self.xfade_reverse
end

-- time duration 
function MetaXFader:set_auto_xfade_time_duration_factor(duration_factor_value)
	self.xfade_time_duration_factor.value = duration_factor_value
end
function MetaXFader:get_auto_xfade_time_duration_factor()
	return self.xfade_time_duration_factor.value
end

-- time duration factor (0.0 .. 1.0). This scales the overall xfade time duration
function MetaXFader:set_auto_xfade_time_duration_factor(duration_factor_value)
	self.xfade_time_duration_factor.value = duration_factor_value
end
function MetaXFader:get_auto_xfade_time_duration_factor()
	return self.xfade_time_duration_factor.value
end

-- device parameter A/B 
function MetaXFader:set_param_a(deviceParameter,update_func)
	self.deviceParamA = deviceParameter
	self.update_func_a = update_func
end
function MetaXFader:get_param_a()
	return self.deviceParamA, self.update_func_a
end
function MetaXFader:set_param_b(deviceParamter,update_func)
	self.deviceParamB = deviceParameter
	self.update_func_b = update_func
end
function MetaXFader:get_param_b()
	return self.deviceParamB, self.update_func_b
end

-- xfade position (set means "manual" xfade !)
function MetaXFader:set_xfade_position(position) 
	-- stop auto xfade
	if (self.xfade_running) then
		self.xfade_running = false
	end
	self:xfade(position)
end
function MetaXFader:get_xfade_position()
	return self.xfade_position
end

--------------------------------------------------------------------------------
-- helper functions
--------------------------------------------------------------------------------

-- simple rounding function, precision: nr of decimal places
-- return int value
local function MetaXFader:round(value,decimalPlaces)
	TRACE("round()")
	return math.floor(value*10^decimalPlaces+0.5)/10^decimalPlaces
end

--------------------------------------------------------------------------------
-- various xfade functions
--------------------------------------------------------------------------------

local function MetaXFader:xfade_dipped(x)
	TRACE("xfade_dipped()")
	return 1.0-x^2
end

local function MetaXFader:xfade_intermediate(x)
	TRACE("xfade_intermediate()")
	return 1.0-x
end

-- constant power xfade
-- provides constant power (n=0), slow fade (n=1), slow cut (n=3), fast cut (n=10)
-- See http://math.stackexchange.com/questions/4621/simple-formula-for-curve-of-dj-crossfader-volume-dipped
-- x: 0.0 .. 1.0
-- y: 0.0 .. 1.0
local function MetaXFader:xfade_const_power(x,n)
	TRACE("xfade_const_power()")
	return math.cos(math.pi*0.25*(((2*x-1)^(2*n+1)+1)))
end

local function MetaXFader:xfade_transition(x)
	TRACE("xfade_transition()")
	local y =2.0*(1.0-x)
	if y >= 1.0 then y = 1.0 end
	return y
end

--------------------------------------------------------------------------------
-- universal xfade function
--------------------------------------------------------------------------------
--
-- crossfades between two device parameters A/B
-- position 0.0 .. 1.0, 0.0 = completely A, 0.5 = A&B, 1.0 = completely B
local function MetaXFader:xfade(position)

	TRACE("xfade()")
	TRACE("XFade position: "..(position*100))
	
	assert(position > 0.0 and position < 1.0)
	assert(self.deviceParamA ~= nil)
	assert(self.deviceParamB ~= nil)	
	
	self.xfade_position.value = position
	local x = position
	local n = 0
	local xfade_func
	
	if (self.xfade_type == nil) then
		xfade_type = prefs.xfade_default_type.value
	end
	
	if (self.xfade_type == XFADE_TYPE_DIPPED) then
		xfade_func = self:xfade_dipped
	elseif (self.xfade_type == XFADE_TYPE_INTERMEDIATE) then
		xfade_func = self:xfade_intermediate
	elseif (self.xfade_type == XFADE_TYPE_CONST_POWER) then
		n = 0
		xfade_func = self:xfade_const_power
	elseif (self.xfade_type == XFADE_TYPE_SLOW_FADE) then
		n = 1
		xfade_func = self:xfade_slow_fade
	elseif (self.xfade_type == XFADE_TYPE_SLOW_CUT) then
		n = 3
		xfade_func = self:xfade_slow_cut
	elseif (self.xfade_type == XFADE_TYPE_FAST_CUT) then
		n = 10
		xfade_func = self:xfade_fast_cut
	elseif (self.xfade_type == XFADE_TYPE_TRANSITION) then
		xfade_func = self:xfade_transition
  end

	self.devParaA.value = xfade_func(x,n)
	TRACE("A="..self.devParaA.name.." Value: "..self.devParaA.value)
	
	self.devParaB.value = xfade_func(1.0-x,n)
	TRACE("B="..self.devParaB.name.." Value: "..self.devParaB.value)
	
	-- optionally call update handlers for A/B
	if (self.update_func_a ~= nil) then
		self.update_func_a(self)
	end
	if (self.update_func_b ~= nil) then
		self.update_func_b(self)
	end
	
	-- TODO: add this to foobar update handler
	--master_track().postfx_volume.value = renoise_vol
	--local foobar_vol = fb2k_volume.value * xfade_func(1.0-x,n)
	--fb2k_set_volume_db(foobar_vol)
end

--------------------------------------------------------------------------------
-- auto xfade functions
--------------------------------------------------------------------------------

-- start auto fade either forwards (e.g. Ren -> FB2K) or reverse (e.g. FB2K -> Ren)
-- TODO: wird durch set_running() ersetzt !!!!
function MetaXFader:xfade_start_stop_auto()
	
	TRACE("xfade_start_auto()")
	
	if (not self.xfade_running) then
	
		self.xfade_reverse = reverse
		self.xfade_running = true
	
		self.xfade_start_timestamp = nil
		self.xfade_last_timestamp = nil
	
		if (not renoise.tool().app_idle_observable:has_notifier(
			self,self.on_idle)) then
			renoise.tool().app_idle_observable:add_notifier(
				self,self.on_idle)
		end
		self:on_idle() -- init
	
	else
		self.xfade_running = false
		if (renoise.tool().app_idle_observable:has_notifier(
			self,self.on_idle)) then
			renoise.tool().app_idle_observable:remove_notifier(
				self,self.on_idle)
		end
	end
end

-- time controlled auto xfade
function MetaXFader:on_idle()

	local current_timestamp = os.clock()
	local xfade_time_duration = 
		self.xfade_default_time_duration.value * self.xfade_time_duration_factor.value
			
	if (self.xfade_start_timestamp == nil) then		
		self.xfade_start_timestamp = current_timestamp		
		self.xfade_last_timestamp = current_timestamp			
	end
	
	-- TODO: 
	-- Problem: einmal haben wir die Zeit und berechnen die Position
	---         einmal haben wir die  Start Position und berechnen die verbleibende Zeit je nach Richtung
	---         da man die current time nicht anpassen kann, muss es über last time geschehen ?
	
	
	TRACE("XFade: Current TS: "..current_timestamp)
	TRACE("XFade: Last TS:"..xfade_last_timestamp)

	-- increase / decrease position
	if (current_timestamp - self.xfade_start_timestamp <= xfade_duration) then
	
		-- TODO: prefs raus !
		local xfade_position
		if (current_timestamp - self.xfade_last_timestamp >= prefs.xfade_update_interval.value) then
			xfade_position = -- TODO
				self.xfade_time_duration.value - (self.xfade_time_duration.value*self.xfade_position.value) /
					current_timestamp - self.xfade_start_timestamp
					
			if (self.xfade_reverse) then
				xfade_position = 1.0 - xfade_position
			end

			self:xfade(xfade_position)
			self.xfade_last_timestamp = os.clock()	
		end
		
	-- end or start position reached
	else
		if (not self.xfade_reverse) then							
			self:xfade(1.0) -- snap to end position		
		else
			self:xfade(0.0) -- snap to start position 
		end		
		self:stop_auto_xfade()
	end
end

local function MetaXFader:stop_auto_xfade()
	
	self.xfade_running = false
	self.xfade_start_timestamp = nil
	self.xfade_last_timestamp = nil	
		
	if (renoise.tool().app_idle_observable:has_notifier(
		self,self.on_idle)) then
			renoise.tool().app_idle_observable:remove_notifier(
			self,self.on_idle)
		end
	end
end