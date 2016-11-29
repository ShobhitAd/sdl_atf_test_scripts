-- UNREADY:
--function function Test:TestStep_PTU_Merge_Messages_Omitted () is not developed
--function testCasesForPolicyTable.flow_PTU_SUCCEESS_HTTP
--should be developed and added to testCasesForPolicyTable

---------------------------------------------------------------------------------------------
-- Requirements summary:
-- [Policies] Merge: PTU into LocalPT (PTU omits "consumer_friendly_messages" section)
-- [HMI API] OnStatusUpdate
--
-- Description:
-- In case the Updated PT omits "consumer_friendly_messages" section,
-- PoliciesManager must maintain the current "consumer_friendly_messages"
-- section in Local PT.
-- 1. Used preconditions
-- SDL is built with "-DEXTENDED_POLICY: HTTP" flag
-- Application is registered.
-- PTU is requested.
-- PTU to be received satisfies data dictionary requirements
-- PTU omits "consumer_friendly_messages" section
-- SDL->HMI: SDL.OnStatusUpdate(UPDATE_NEEDED)
-- SDL->HMI:SDL.PolicyUpdate(file, timeout, retry[])
-- HMI -> SDL: SDL.GetURLs (<service>)
-- HMI->SDL: BasicCommunication.OnSystemRequest ('url', requestType:HTTP)
-- SDL->app: OnSystemRequest ('url', requestType:HTTP, fileType="JSON")
-- app->SDL: SystemRequest(requestType=HTTP)
-- SDL->HMI: SystemRequest(requestType=HTTP, fileName)
-- HMI->SDL: SystemRequest(SUCCESS)
-- 2. Performed steps
-- HMI->SDL: OnReceivedPolicyUpdate(policy_file) according to data dictionary
-- SDL->HMI: OnStatusUpdate(UP_TO_DATE)
-- Expected result:
-- SDL maintains the current "consumer_friendly_messages" section in Local PT
--(no updates on merge)
-- SDL replaces the following sections of the Local Policy Table with the
--corresponding sections from PTU: module_config, functional_groupings and app_policies

---------------------------------------------------------------------------------------------

--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"

--[[ Required Shared libraries ]]
local commonSteps = require('user_modules/shared_testcases/commonSteps')
local commonFunctions = require('user_modules/shared_testcases/commonFunctions')
local testCasesForPolicyTable = require('user_modules/shared_testcases/testCasesForPolicyTable')
local testCasesForPolicyTableSnapshot = require ('user_modules/shared_testcases/testCasesForPolicyTableSnapshot')

--[[ General Precondition before ATF start ]]
commonSteps:DeleteLogsFileAndPolicyTable()

--ToDo: shall be removed when issue: "ATF does not stop HB timers by closing session and connection" is fixed
config.defaultProtocolVersion = 2

--[[ General Settings for configuration ]]
Test = require('connecttest')
require('cardinalities')
require('user_modules/AppTypes')

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")
--TODO(mmihaylova-banska): Function should be implmented
function Test:TestStep_PTU_Merge_Messages_Omitted ()
  testCasesForPolicyTable:flow_PTU_SUCCEESS_HTTP()
  --[[Start get data from PTS]]
  --TODO(istoimenova): function for reading INI file should be implemented
  --local SystemFilesPath = commonSteps:get_data_from_SDL_ini("SystemFilesPath")
  local SystemFilesPath = "/tmp/fs/mp/images/ivsu_cache/"

  -- Check SDL snapshot is created correctly and get needed data
  testCasesForPolicyTableSnapshot:verify_PTS(true, {app_id}, {device_id}, {hmi_app_id})

  local endpoints = {}
  for i = 1, #testCasesForPolicyTableSnapshot.pts_endpoints do
    if (testCasesForPolicyTableSnapshot.pts_endpoints[i].service == "0x07") then
      endpoints[1] = { url = testCasesForPolicyTableSnapshot.pts_endpoints[i].value, appID = nil}
    end
  end

  local RequestId_GetUrls = self.hmiConnection:SendRequest("SDL.GetURLS", { service = 7 })
  EXPECT_HMIRESPONSE(RequestId_GetUrls,{result = {code = 0, method = "SDL.GetURLS", urls = endpoints} } )
  :Do(function(_,_)
      self.hmiConnection:SendNotification("BasicCommunication.OnSystemRequest",
        { requestType = "HTTP", fileName = ptu_file_name})
      EXPECT_NOTIFICATION("OnSystemRequest", {requestType = "HTTP"})
      :Do(function(_,_)

          EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate",
            {status = "UPDATING"}, {status = "UP_TO_DATE"}):Times(2)

          local CorIdSystemRequest = self.mobileSession:SendRPC("SystemRequest", {requestType = "HTTP", fileName = ptu_file_name, appID = app_id}, ptu_file_path..ptu_file)
          EXPECT_HMICALL("BasicCommunication.SystemRequest",{ requestType = "HTTP", fileName = SystemFilesPath..ptu_file_name })
          :Do(function(_,_data1)
              self.hmiConnection:SendResponse(_data1.id,"BasicCommunication.SystemRequest", "SUCCESS", {})
              self.hmiConnection:SendNotification("SDL.OnReceivedPolicyUpdate", { policyfile = SystemFilesPath..ptu_file_name})
            end)
          EXPECT_RESPONSE(CorIdSystemRequest, { success = true, resultCode = "SUCCESS"})
        end)
    end)
end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")
function Test:Postcondition_Force_Stop_SDL()
  commonFunctions:SDLForceStop(self)
end

return Test
