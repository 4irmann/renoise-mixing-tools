--[[----------------------------------------------------------------------------
  
  helper functions
  
  Taken from GlobalMidiActions.lua, Author: taktik 
  
  This Code is not licensed under the otherwise 
  mentioned Apache License !!!!!  
----------------------------------------------------------------------------]]--

function song()
  return renoise.song()
end

-- sequencer_track

function sequencer_track(track_index)
  if (track_index <= song().sequencer_track_count) then
    return song():track(track_index)
  else
    return nil
  end
end

-- master_track

function master_track()
  -- master track is always behind the sequencer tracks
  return song():track(song().sequencer_track_count + 1)
end

-- clamp_value

function clamp_value(value, min_value, max_value)
  return math.min(max_value, math.max(value, min_value))
end


-- wrap_value

function wrap_value(value, min_value, max_value)
  local range = max_value - min_value + 1
  assert(range > 0, "invalid range")

  while (value < min_value) do
    value = value + range
  end

  while (value > max_value) do
    value = value - range
  end

  return value
end


-- quantize_value

function quantize_value(value, quantum)
  if (value >= 0) then
     value = value + quantum / 2
  else
     value = value - quantum / 2
  end

  return math.floor(value / quantum) * quantum
end


--------------------------------------------------------------------------------

-- boolean_message_value

local function boolean_message_value(message, value)
  if (message:is_switch()) then
    return message.boolean_value
  else
    return value
  end
end


-- toggle_message_value

function toggle_message_value(message, value)
  if (message:is_trigger()) then
    return not value
  else
    return value
  end
end


-- message_value_with_offset

function message_value_with_offset(message, value,
  offset, min_value, max_value)

  if (message:is_abs_value()) then
    return clamp_value(message.int_value + offset, min_value, max_value)

  elseif (message:is_rel_value()) then
    return clamp_value(value + message.int_value, min_value, max_value)

  else
    return value
  end
end


-- message_value

function message_value(message, value, min_value, max_value)
  return message_value_with_offset(message, value, 0, min_value, max_value)
end


-- inc_message_value

function inc_message_value(message, value, min_value, max_value)
  if (message:is_trigger()) then
    return clamp_value(value + 1, min_value, max_value)
  else
    return value
  end
end


-- dec_message_value

function dec_message_value(message, value, min_value, max_value)
  if (message:is_trigger()) then
    return clamp_value(value - 1, min_value, max_value)
  else
    return value
  end
end


-- parameter_message_value

function parameter_message_value(message, parameter)

  local new_value = parameter.value
  local quantum = parameter.value_quantum

  local parameter_min = (parameter.value_max - parameter.value_min) *
    message.value_min_scaling + parameter.value_min

  local parameter_max = (parameter.value_max - parameter.value_min) *
    message.value_max_scaling + parameter.value_min

  if (quantum > 0) then
    new_value = quantize_value(new_value, quantum)
    
    parameter_min = quantize_value(parameter_min, quantum)
    parameter_max = quantize_value(parameter_max, quantum)
  end

  local parameter_range = parameter_max - parameter_min

  if (message:is_abs_value()) then
    new_value = parameter_min + (message.int_value / 127 * parameter_range)

    if (parameter.polarity == renoise.DeviceParameter.POLARITY_BIPOLAR) then
      local center_value = parameter.value_min +
        (parameter.value_max - parameter.value_min) / 2;
      if (math.abs(center_value - new_value) < parameter_range / 128) then
        -- snap to center
        new_value = center_value
      end
    end

  elseif (message:is_rel_value()) then
    if (quantum > 0) then
      if (message.int_value > 0) then
        new_value = new_value + quantum
      else
        new_value = new_value - quantum
      end
    else
      new_value = new_value + parameter_range / 127 * message.int_value;

      if (parameter.polarity == renoise.DeviceParameter.POLARITY_BIPOLAR) then
        local center_value = parameter.value_min + 
          (parameter.value_max - parameter.value_min) / 2;
        if (math.abs(center_value - new_value) < parameter_range / 128) then
          -- snap to center
          new_value = center_value
        end
      end
    end

    new_value = clamp_value(new_value,
      math.min(parameter_min, parameter_max),
      math.max(parameter_min, parameter_max)
    )

  elseif (message:is_switch()) then
    if (message.boolean_value) then
      new_value = parameter_max
    else
      new_value = parameter_min
    end

  elseif (message:is_trigger()) then
    if (quantum > 0) then
      -- walk through quantized values
      if (parameter_max > parameter_min) then
        new_value = new_value + quantum;
        if (new_value > parameter_max) then
          new_value = parameter_min
        end
      elseif (parameter_max < parameter_min) then
        new_value = new_value - quantum
        if (new_value < parameter_max) then
          new_value = parameter_min
        end
      end
    else
      -- toggle between min/max
      if (parameter.value > parameter_min + parameter_range / 2) then
        new_value = parameter_min
      else
        new_value = parameter_max
      end
    end
  end

  return new_value
end
