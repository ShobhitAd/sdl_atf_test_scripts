---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0221-multiple-modules.md
-- Description:
--  Check of GetInteriorVehicleDataConsent RPC processing with multiple moduleIds and module allocation
--  is performed without asking driver if access mode is ASK_DRIVER and the decisions for modules are cached
--
-- 1) SDL and HMI are started
-- 2) HMI sent RC capabilities with modules of each type (allowMultipleAccess: true) to SDL
-- 3) RC access mode set from HMI: ASK_DRIVER
-- 4) Mobile is connected to SDL
-- 5) App1 and App2 (appHMIType: ["REMOTE_CONTROL"]) are registered from Mobile
-- 6) App1 and App2 are within serviceArea of modules
-- 7) HMI level of App1 is BACKGROUND;
--    HMI level of App2 is FULL
-- 8) RC modules are free
--
-- Steps:
-- 1) Allocate free modules (moduleType: <moduleType>, moduleId: <moduleId1>)
--     and (moduleType: <moduleType>, moduleId: <moduleId2>) to App2 via SetInteriorVehicleData RPC
--   Check:
--    SDL responds on SetInteriorVehicleData RPC with resultCode: SUCCESS
--    SDL does not send GetInteriorVehicleDataConsent RPC to HMI
--    SDL allocates module (moduleType: <moduleType>, moduleId: <moduleId>) to App2
--     and sends appropriate OnRCStatus notifications
-- 2) Activate App1 and send GetInteriorVehicleDataConsent RPC for multiple modules of each RC module type
--     sequentially (moduleType: <moduleType>, moduleIds: [<moduleId1>, <moduleId2>]) from App1
--    HMI responds on GetInteriorVehicleDataConsent request with (moduleType: <moduleType>, allowed: [true, false])
--   Check:
--    SDL sends RC.GetInteriorVehicleDataConsent request to HMI with
--     (moduleType: <moduleType>, moduleIds:[<moduleId1>, <moduleId2>])
--    SDL responds on GetInteriorVehicleDataConsent RPC with resultCode:"SUCCESS", success:true
--    SDL does not send OnRCStatus notifications to HMI and Apps
-- 3) Activate App1 and send GetInteriorVehicleDataConsent RPC for multiple modules of each RC module type
--     sequentially (moduleType: <moduleType>, moduleIds: [<moduleId1>, <moduleId2>]) from App1
--   Check:
--    SDL does not send RC.GetInteriorVehicleDataConsent request to HMI
--    SDL responds on GetInteriorVehicleDataConsent RPC with resultCode:"SUCCESS", success:true, allowed: [true, true]
--    SDL does not send OnRCStatus notifications to HMI and Apps
-- 4) Try to reallocate modules (moduleType: <moduleType>, moduleId: <moduleId1>)
--     and (moduleType: <moduleType>, moduleId: <moduleId2>) to App1 via SetInteriorVehicleData RPC sequentially
--   Check:
--    SDL does not send GetInteriorVehicleDataConsent RPC to HMI
--    SDL allocates module (moduleType: <moduleType>, moduleId: <moduleId1>)
--     and rejects allocation of module (moduleType: <moduleType>, moduleId: <moduleId2>) to App1
--     and sends appropriate OnRCStatus notifications to HMI and Apps
--    SDL responds on SetInteriorVehicleData RPC (moduleType: <moduleType>, moduleId: <moduleId1>)
--     with resultCode: SUCCESS
--    SDL responds on SetInteriorVehicleData RPC (moduleType: <moduleType>, moduleId: <moduleId2>)
--     with resultCode: REJECTED
---------------------------------------------------------------------------------------------------
local runner = require('user_modules/script_runner')
local common = require("test_scripts/RC/MultipleModules/commonRCMulModules")

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local appLocation = {
  [1] = common.grid.BACK_RIGHT_PASSENGER,
  [2] = common.grid.BACK_CENTER_PASSENGER
}

local accessMode = "ASK_DRIVER"

local testServiceArea = common.grid.BACK_SEATS

local rcAppIds = { 1, 2 }

local sdlDecisions = {}
local rcCapabilities = common.initHmiRcCapabilitiesMultiConsent(testServiceArea)
local testModules = common.buildTestModulesStruct(rcCapabilities)

--[[ Local Variables ]]
local function driverConsentForReallocationToApp(pAppId, pModuleType, pModuleConsentArray, pRCAppIds, pAccessMode)
  for moduleId in pairs(pModuleConsentArray) do
    sdlDecisions[moduleId] = true  -- SDL makes decision without asking driver for this module
  end
  common.driverConsentForReallocationToApp(pAppId, pModuleType, pModuleConsentArray,
                                           pRCAppIds, pAccessMode, sdlDecisions)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Prepare preloaded policy table", common.preparePreloadedPT, { rcAppIds })
runner.Step("Prepare RC modules capabilities and initial modules data", common.initHmiDataState, { rcCapabilities })
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start, { rcCapabilities })
runner.Step("Set RA mode: ".. accessMode, common.defineRAMode, { true, accessMode })
runner.Step("Register App1", common.registerAppWOPTU, { 1 })
runner.Step("Register App2", common.registerAppWOPTU, { 2 })
runner.Step("Activate App1", common.activateApp, { 1 })
runner.Step("Send user location of App1 (Back Seat)", common.setUserLocation, { 1, appLocation[1] })
runner.Step("Activate App2", common.activateApp, { 2 })
runner.Step("Send user location of App2 (Back seat)", common.setUserLocation, { 2, appLocation[2] })

for moduleType, consentArray in pairs(testModules) do
  for moduleId in pairs(consentArray) do
    runner.Step("Allocate module [" .. moduleType .. ":" .. moduleId .. "] to App2",
      common.rpcSuccess, { moduleType, moduleId, 2, "SetInteriorVehicleData" })
  end
end

runner.Title("Test")
runner.Step("Activate App1", common.activateApp, { 1 })
for moduleType, consentArray in pairs(testModules) do
  runner.Step("Allow " .. moduleType .. " modules reallocation to App1",
  common.driverConsentForReallocationToApp, { 1, moduleType, consentArray, rcAppIds, accessMode })
end

for moduleType, consentArray in pairs(testModules) do
  runner.Step("Allow " .. moduleType .. " modules reallocation to App1 from cache",
  driverConsentForReallocationToApp, { 1, moduleType, consentArray, rcAppIds, accessMode })
end

for moduleType, consentArray in pairs(testModules) do
  for moduleId, isAllowed in pairs(consentArray) do
    runner.Step("Try to reallocate " .. tostring(isAllowed and "allowed" or "disallowed")
        .. " module [" .. moduleType .. ":" .. moduleId .. "] to App1",
      common.getAllocationFunction(isAllowed, false),
      { 1, moduleType, moduleId, nil, rcAppIds })
  end
end

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
