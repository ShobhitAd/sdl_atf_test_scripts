---------------------------------------------------------------------------------------------
-- Requirements summary:
-- [GENIVI] [Policy] "HTTP" flow: SDL must be build with "-DEXTENDED_POLICY: HTTP"
--
-- Description:
-- To "switch on" the "HTTP" flow of PolicyTableUpdate feature
-- -> SDL should be built with _-DEXTENDED_POLICY: HTTP flag
-- 1. Performed steps
-- Build SDL with flag above
--
-- Expected result:
-- SDL is successfully built
-- The flag EXTENDED_POLICY is set to HTTP
-- PTU passes successfully
---------------------------------------------------------------------------------------------

--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"
config.defaultProtocolVersion = 2

--[[ Required Shared libraries ]]
local commonFunctions = require ('user_modules/shared_testcases/commonFunctions')
local commonSteps = require('user_modules/shared_testcases/commonSteps')

--[[ General Precondition before ATF start ]]
commonSteps:DeleteLogsFileAndPolicyTable()

--[[ General Settings for configuration ]]
Test = require('connecttest')
require('cardinalities')
require('user_modules/AppTypes')
local mobile_session = require('mobile_session')
require('user_modules/AppTypes')

config.application2.registerAppInterfaceParams.appName = "Media Application"
config.application2.registerAppInterfaceParams.appID = "MyTestApp"

--[[ Local Variables ]]
local filePTU = "files/ptu.json"

--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")
function Test:SYSTEM_UP_TO_DATE()
  commonFunctions:check_ptu_sequence_partly(self, filePTU, "ptu.json")
end

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")
function Test:TestStep_OpenNewSession()
  self.mobileSession2 = mobile_session.MobileSession(self, self.mobileConnection)
  self.mobileSession2:StartService(7)
end

function Test:TestStep_Trigger_PTU_Check_HTTP_flow()
  local corId = self.mobileSession2:SendRPC("RegisterAppInterface", config.application2.registerAppInterfaceParams)
  EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered", { application = { appName = config.application2.registerAppInterfaceParams.appName }})
   :Do(function()
     EXPECT_NOTIFICATION("OnSystemRequest", {requestType = "HTTP"})
      :Do(function()
          local CorIdSystemRequest = self.mobileSession:SendRPC ("SystemRequest",
            { requestType = "HTTP", fileName = "PTU" }, filePTU)
          EXPECT_RESPONSE(CorIdSystemRequest, {success = true, resultCode = "SUCCESS"})
          
        end)
      self.mobileSession2:ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
      self.mobileSession2:ExpectNotification("OnPermissionsChange")
   end)
    EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate")
     :ValidIf(function(exp,data)
       if exp.occurences == 1 and data.params.status == "UPDATE_NEEDED" then
         return true
       elseif exp.occurences == 2 and data.params.status == "UPDATING" then
         return true
       elseif exp.occurences == 3 and data.params.status == "UP_TO_DATE" then
         return true
        end
        return false
    end)
     :Times(3)
end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")
function Test.Postcondition_SDLStop()
  StopSDL()
end