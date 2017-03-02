---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [PTU] [GENIVI] PolicyTableUpdate is failed by any reason and "ForceProtectedService"=ON at .ini file
-- [PTU] [GENIVI] SDL must start PTU for navi app right after app successfully registration
--
-- Description:
-- In case SDL starts PolicyTableUpdate in case of no "certificate" at "module_config" section at LocalPT
-- and PolicyTableUpdate is failed by any reason even after retry strategy (please see related req-s HTTP flow and Proprietary flow)
-- and "ForceProtectedService" is ON(0x07, 0x0A, 0x0B, 0x0F) at .ini file
-- and app sends StartService (<any_serviceType>, encypted=true) to SDL
-- SDL must respond StartService (NACK) to this mobile app
--
-- 1. Used preconditions:
-- RPC SetAudioStreamingIndicator is allowed by policy
-- Navi app exists in LP, no certificate in module_config
--
-- 2. Performed steps
-- 2.1 Register and activate navi application.
-- 2.2 Wait PTU retry sequence to elapse.
-- 2.3 Send Audio service.
-- 2.4 Send Video service.
-- 2.5 Send RPC service.
-- 2.6 Send Hybrid service.
--
-- Expected result:
-- 1. SDL should trigger PTU: SDL.OnStatusUpdate(UPDATE_NEEDED)
-- 2. SDL invalidates PTU
-- 3. SDL should return StartServiceNACK to Audio
-- 4. SDL should return StartServiceNACK to Video
-- 5. SDL should return StartServiceNACK to RPC
-- 6. SDL should return StartServiceNACK to Hybrid
---------------------------------------------------------------------------------------------

--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"
config.application1.registerAppInterfaceParams.appHMIType = {"NAVIGATION"}

--[[ Required Shared libraries ]]
local commonFunctions = require ('user_modules/shared_testcases/commonFunctions')
local commonSteps = require('user_modules/shared_testcases/commonSteps')
local commonTestCases = require('user_modules/shared_testcases/commonTestCases')
local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')
local testCasesForPolicyCeritificates = require('user_modules/shared_testcases/testCasesForPolicyCeritificates')
local events = require('events')
local Event = events.Event

--[[ Local variables ]]
local time_wait = (60 + 61 + 62 + 62 + 62 + 62)*1000

--[[ General Precondition before ATF start ]]
commonPreconditions:BackupFile("smartDeviceLink.ini")
commonFunctions:write_parameter_to_smart_device_link_ini("ForceProtectedService", "0x07, 0x0A, 0x0B, 0x0F")
testCasesForPolicyCeritificates.update_preloaded_pt(config.application1.registerAppInterfaceParams.appID, false, {1,1,1,1,1})
testCasesForPolicyCeritificates.create_ptu_certificate_exist(nil, true)
commonSteps:DeletePolicyTable()
commonSteps:DeleteLogsFiles()

--[[ General Settings for configuration ]]
Test = require('user_modules/connecttest_resumption')
require('user_modules/AppTypes')

--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")

function Test:Precondition_ActivateApp()
  commonSteps:ActivateAppInSpecificLevel(self, self.applications[config.application1.registerAppInterfaceParams.appName])
  EXPECT_NOTIFICATION("OnHMIStatus", {systemContext = "MAIN", hmiLevel = "FULL"})
end

function Test.Precondition_PolicyTableUpdate_retry_sequence_elapse()
  print("Wait retry sequence to elapse")

  EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate",
    {status="UPDATE_NEEDED"}, {status = "UPDATING"},
    {status="UPDATE_NEEDED"}, {status = "UPDATING"},
    {status="UPDATE_NEEDED"}, {status = "UPDATING"},
    {status="UPDATE_NEEDED"}, {status = "UPDATING"},
    {status="UPDATE_NEEDED"})
  :Times(9)
  :Timeout(time_wait)
  :Do(function(exp, data) print("exp: ".. exp.occurences) print("data = "..data.params.status)end)

  commonTestCases:DelayedExp(time_wait)
end

function Test:TestStep_Audio_NACK()
  self.mobileSession.correlationId = self.mobileSession.correlationId + 1

  local msg = {
    serviceType = 10,
    frameInfo = 1,
    frameType = 0,
    rpcCorrelationId = self.mobileSession.correlationId,
    encryption = true
  }
  self.mobileSession:Send(msg)

  local startserviceEvent = Event()
  startserviceEvent.matches =
  function(_, data)
    return ( data.frameType == 0 and data.serviceType == 10)
  end

  self.mobileSession:ExpectEvent(startserviceEvent, "Service 10: StartServiceNACK")
  :ValidIf(function(_, data)
      if data.frameInfo == 2 then
        commonFunctions:printError("Service 10: StartServiceACK is received")
        return false
      elseif data.frameInfo == 3 then
        print("Service 10: Audio NACK")
        return true
      else
        commonFunctions:printError("Service 10: StartServiceACK/NACK is not received at all.")
        return false
      end
    end)

  commonTestCases:DelayedExp(10000)
end

function Test:TestStep_Video_NACK()
  self.mobileSession.correlationId = self.mobileSession.correlationId + 1

  local msg = {
    serviceType = 11,
    frameInfo = 1,
    frameType = 0,
    rpcCorrelationId = self.mobileSession.correlationId,
    encryption = true
  }
  self.mobileSession:Send(msg)

  local startserviceEvent = Event()
  startserviceEvent.matches =
  function(_, data)
    return ( data.frameType == 0 and data.serviceType == 11)
  end

  self.mobileSession:ExpectEvent(startserviceEvent, "Service 11: StartServiceNACK")
  :ValidIf(function(_, data)
      if data.frameInfo == 2 then
        commonFunctions:printError("Service 11: StartServiceACK is received")
        return false
      elseif data.frameInfo == 3 then
        print("Service 11: Audio NACK")
        return true
      else
        commonFunctions:printError("Service 11: StartServiceACK/NACK is not received at all.")
        return false
      end
    end)

  commonTestCases:DelayedExp(10000)
end

function Test:TestStep_RPC_NACK()
  self.mobileSession.correlationId = self.mobileSession.correlationId + 1

  local msg = {
    serviceType = 7,
    frameInfo = 0,
    rpcType = 0,
    rpcFunctionId = 48,
    encryption = true,
    rpcCorrelationId = self.mobileSession.correlationId,
    payload = '{ "audioStreamingIndicator" : "PAUSE" }'
  }
  self.mobileSession:Send(msg)

  local startserviceEvent = Event()
  startserviceEvent.matches =
  function(_, data)
    return ( data.frameType == 0 and data.serviceType == 7)
  end

  self.mobileSession:ExpectEvent(startserviceEvent, "Service 7: StartServiceNACK")
  :ValidIf(function(_, data)
      if data.frameInfo == 2 then
        commonFunctions:printError("Service 7: StartServiceACK is received")
        return false
      elseif data.frameInfo == 3 then
        print("Service 7: Audio NACK")
        return true
      else
        commonFunctions:printError("Service 7: StartServiceACK/NACK is not received at all.")
        return false
      end
    end)

  commonTestCases:DelayedExp(10000)
end

function Test:TestStep_Hybrid_NACK()
  self.mobileSession.correlationId = self.mobileSession.correlationId + 1

  local msg = {
    serviceType = 15,
    frameInfo = 0,
    rpcType = 0,
    rpcFunctionId = 48,
    encryption = true,
    rpcCorrelationId = self.mobileSession.correlationId,
    payload = '{ "audioStreamingIndicator" : "PAUSE" }',
    binaryData = '{ "audioStreamingIndicator" : "PAUSE" }'
  }
  self.mobileSession:Send(msg)

  local startserviceEvent = Event()
  startserviceEvent.matches =
  function(_, data)
    return ( data.frameType == 0 and data.serviceType == 15)
  end

  self.mobileSession:ExpectEvent(startserviceEvent, "Service 15: StartServiceNACK")
  :ValidIf(function(_, data)
      if data.frameInfo == 2 then
        commonFunctions:printError("Service 15: StartServiceACK is received")
        return false
      elseif data.frameInfo == 3 then
        print("Service 15: Audio NACK")
        return true
      else
        commonFunctions:printError("Service 15: StartServiceACK/NACK is not received at all.")
        return false
      end
    end)

  commonTestCases:DelayedExp(10000)
end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")

function Test.Postcondition_Restore_files()
  os.execute( " rm -f files/ptu_certificate_exist.json" )
  commonPreconditions:RestoreFile("smartDeviceLink.ini")
  commonPreconditions:RestoreFile("sdl_preloaded_pt.json")
end

function Test.Postcondition_Stop()
  StopSDL()
end

return Test
