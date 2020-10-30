local M = {}
local prev_electrics = {}
local prev_signal_electrics = {}
local timer = 0
local ignored_keys = {
  throttle = true,
  throttle_input = true,
  brake = true,
  brake_input = true,
  clutch = true,
  clutch_input = true,
  clutchRatio = true,
  parkingbrake = true,
  parkingbrake_input = true,
  steering = true,
  steering_input = true,
  reverse = true,
  lights = true,
  turnsignal = true,
  hazard = true,
  hazard_enabled = true,
  signal_R = true,
  signal_L = true,
  gear = true,
  gear_M = true,
  gear_A = true,
  gearIndex = true,
  exhaustFlow = true,
  engineLoad = true,
  airspeed = true,
  axle_FL = true,
  airflowspeed = true,
  watertemp = true,
  driveshaft_F = true,
  rpmspin = true,
  wheelspeed = true,
  rpm = true,
  altitude = true,
  avgWheelAV = true,
  oiltemp = true,
  rpmTacho = true,
  axle_FR = true,
  fuel_volume = true,
  driveshaft = true,
  fuel = true,
  engineThrottle = true,
  fuelVolume = true,
  turboSpin = true,
  turboRPM = true,
  turboBoost = true,
  virtualAirspeed = true,
  turboRpmRatio = true,
  lockupClutchRatio = true,
  abs = true,
  absActive = true,
  tcs = true,
  tcsActive = true,
  esc = true,
  escActive = true,
  brakelights = true
}

local function send()
  local data = {
    vehicle_id = obj:getID(),
    throttle_input = electrics.values.throttle_input,
    brake_input = electrics.values.brake_input,
    clutch = electrics.values.clutch_input,
    parkingbrake = electrics.values.parkingbrake_input,
    steering_input = electrics.values.steering_input,
  }
  obj:queueGameEngineLua("network.send_messagepack(2, false, \'"..jsonEncode(data).."\')")

  local diff_count = 0
  local data = {
    vehicle_id = obj:getID(),
    diff = {}
  }
  for key, value in pairs(electrics.values) do
    if not ignored_keys[key] and type(value) == 'number' then
      if prev_electrics[key] ~= value then
        data.diff[key] = value
        diff_count = diff_count + 1
      end
      prev_electrics[key] = value
    end
  end
  
  if diff_count > 0 then
    obj:queueGameEngineLua("network.send_messagepack(15, true, \'"..jsonEncode(data).."\')")
  end
end

local function apply(data)
  local data = jsonDecode(data)
  input.event("throttle", data[2], 1)
  input.event("brake", data[3], 2)
  input.event("steering", data[6], 2)
  input.event("parkingbrake", data[5], 2)
  input.event("clutch", data[4], 1)
end

local function apply_diff_signals(diff)
  local signal_left_input = diff["signal_left_input"] or prev_signal_electrics["signal_left_input"] or 0
  local signal_right_input = diff["signal_right_input"] or prev_signal_electrics["signal_right_input"] or 0
  local hazard_enabled = (signal_left_input > 0.5 and signal_right_input > 0.5)
  
  if hazard_enabled then
    electrics.set_warn_signal(1)
  else
    electrics.set_warn_signal(0)
    if signal_left_input > 0.5 then
      electrics.toggle_left_signal()
    elseif signal_right_input > 0.5 then
      electrics.toggle_right_signal()
    end
  end
  
  prev_signal_electrics["signal_left_input"] = signal_left_input
  prev_signal_electrics["signal_right_input"] = signal_right_input
end

local function apply_diff(data)
  local diff = jsonDecode(data)
  apply_diff_signals(diff)
  for k, v in pairs(diff) do
    electrics.values[k] = v
    if k == "lights_state" then
      electrics.setLightsState(v)
    elseif k == "fog" then
      electrics.set_fog_lights(v)
    elseif k == "lightbar" then
      electrics.set_lightbar_signal(v)
    elseif k == "engineRunning" then
      controller.mainController.setStarter(v > 0.5)
    elseif k == "horn" then
      electrics.horn(v > 0.5)
    end
  end
end

local function kissInit()
  -- Ignore powertrain electrics
  local devices = powertrain.getDevices()
  for _, device in pairs(devices) do
    if device.electricsName and device.visualShaftAngle then
      ignored_keys[device.electricsName] = true
    end
    if device.electricsThrottleName then 
      ignored_keys[device.electricsThrottleName] = true
    end
    if device.electricsThrottleFactorName then
      ignored_keys[device.electricsThrottleFactorName] = true
    end
    if device.electricsClutchRatio1Name then
      ignored_keys[device.electricsClutchRatio1Name] = true
    end
    if device.electricsClutchRatio2Name then
      ignored_keys[device.electricsClutchRatio2Name] = true
    end
  end
  
  -- Ignore lightbar electrics
  for _, controller in pairs(v.data.controller) do
    if controller.name == "lightbar" and controller.modes then
        local modes = tableFromHeaderTable(controller.modes)
        for _, vm in pairs(modes) do
          local configEntries = tableFromHeaderTable(deepcopy(vm.config))
          for _, j in pairs(configEntries) do
            ignored_keys[j.electric] = true
          end 
        end
    end
  end
end

M.send = send
M.apply = apply
M.apply_diff = apply_diff

M.kissInit = kissInit

return M
