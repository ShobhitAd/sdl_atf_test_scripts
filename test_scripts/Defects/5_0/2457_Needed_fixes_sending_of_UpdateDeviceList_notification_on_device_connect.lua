---------------------------------------------------------------------------------------------------
-- User story: https://github.com/smartdevicelink/sdl_core/issues/2457
--
-- Description:
-- Steps to reproduce:
-- 1) HMI and SDL started, connect mobile device.
-- Expected:
-- 1) SDL has to notify system with BC.UpdateDeviceList on device connect
-- even if device does not have any SDL-enabled applications running.
---------------------------------------------------------------------------------------------------
-- [[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('user_modules/sequences/actions')
local utils = require("user_modules/utils")
local SDL = require("SDL")

--[[ Conditions to skip test ]]
if config.defaultMobileAdapterType ~= "TCP" then
  runner.skipTest("Test is applicable only for TCP connection")
end

-- [[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

-- [[ Local function ]]
local function getDeviceList()
  local connection = common.mobile.getConnection()
  local weDevice = {
    id = utils.buildDeviceMAC("WS"),
    name = "Web Engine",
    transportType = "WEBENGINE_WEBSOCKET"
  }
  local deviceList = {
    [1] = {
      id = utils.getDeviceMAC(connection.host, connection.port),
      name = utils.getDeviceName(connection.host, connection.port),
      transportType = "WIFI"
    }
  }
  if SDL.buildOptions.webSocketServerSupport == "ON" then
    table.insert(deviceList, 1, weDevice)
  end
  return deviceList
end

local function startWOMobile()
  local event = common.run.createEvent()
  common.init.SDL()
  :Do(function()
      common.init.HMI()
      :Do(function()
        common.init.HMI_onReady()
          :Do(function()
              common.hmi.getConnection():RaiseEvent(event, "Start event")
            end)
        end)
    end)
  return common.hmi.getConnection():ExpectEvent(event, "Start event")
end

local function connectMobile()
  common.init.connectMobile()
  utils.printTable(getDeviceList())
  common.getHMIConnection():ExpectRequest("BasicCommunication.UpdateDeviceList", {
    deviceList = getDeviceList()
  })
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL and HMI", startWOMobile)

-- [[ Test ]]
runner.Title("Test")
runner.Step("Connect Mobile", connectMobile)

-- [[ Postconditions ]]
runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
