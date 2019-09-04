---------------------------------------------------------------------------------------------------
-- User story: https://github.com/smartdevicelink/sdl_requirements/issues/11
-- Use case: https://github.com/smartdevicelink/sdl_requirements/blob/master/detailed_docs/rc_enabling_disabling.md
-- Item: Use Case 2: Main Flow
--
-- Requirement summary:
-- [SDL_RC] Resource allocation based on access mode
--
-- Description:
-- In case:
-- RC_functionality is disabled on HMI and HMI sends notification OnRemoteControlSettings
--  (allowed:true, <any_accessMode>)
--
-- SDL must:
-- 1) store RC state allowed:true and received from HMI internally
-- 2) allow RC functionality for applications with REMOTE_CONTROL appHMIType
--
-- Case: accessMode = "ASK_DRIVER"
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonRC = require('test_scripts/RC/commonRC')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Functions ]]
local function disableRcFromHmi()
  commonRC.defineRAMode(false, nil)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start)
runner.Step("RAI1", commonRC.registerAppWOPTU)
runner.Step("RAI2", commonRC.registerAppWOPTU, { 2 })
runner.Step("Disable RC from HMI", disableRcFromHmi)

runner.Title("Test")
runner.Step("Enable RC from HMI with ASK_DRIVER access mode", commonRC.defineRAMode, { true, "ASK_DRIVER"})
for _, mod in pairs(commonRC.modules)  do
  runner.Step("Activate App2", commonRC.activateApp, { 2 })
  runner.Step("Check module " .. mod .." App2 SetInteriorVehicleData allowed",
      commonRC.rpcAllowed, { mod, 2, "SetInteriorVehicleData" })
  runner.Step("Activate App1", commonRC.activateApp)
  runner.Step("Check module " .. mod .." App1 SetInteriorVehicleData allowed with driver consent",
      commonRC.rpcAllowedWithConsent, { mod, 1, "SetInteriorVehicleData" })
  runner.Step("Activate App2", commonRC.activateApp, { 2 })
  runner.Step("Check module " .. mod .." App2 ButtonPress allowed with driver consent",
      commonRC.rpcAllowedWithConsent, { mod, 2, "ButtonPress" })
  runner.Step("Activate App1", commonRC.activateApp)
  runner.Step("Check module " .. mod .." App1 ButtonPress allowed with driver consent",
      commonRC.rpcAllowed, { mod, 1, "ButtonPress" })
end

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
