---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [ResetGlobalProperties] "MENUICON" reset
-- [INI file] [ApplicationManager] MenuIcon
--
-- Description:
-- Check that SDL correctly retrievs menuIcon from INI file in case ResetGlobalProperties
-- is sent only with MENUICON in Properties array.
--
-- 1. Used preconditions:
-- Check that menuIcon exists in INI file.
-- ResetGlobalProperties and SetGlobalProperties is allowed by policy.
-- menuIcon will be re-written in INI file with empty path
-- Send SetGlobalProperties(menuIcon = { value = "action.png", imageType = "DYNAMIC" })
--
-- 2. Performed steps
-- Send ResetGlobalProperties(properties = "MENUICON")
--
-- Expected result:
-- 1. UI.SetGlobalProperties() is received without parameter menuIcon
-- 2. TTS.SetGlobalProperties is not sent.
---------------------------------------------------------------------------------------------

--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"

--[[ Required Shared libraries ]]
local commonPreconditions = require ('user_modules/shared_testcases/commonPreconditions')
local commonSteps = require ('user_modules/shared_testcases/commonSteps')
local testCasesForPolicyTable = require ('user_modules/shared_testcases/testCasesForPolicyTable')
local commonFunctions = require ('user_modules/shared_testcases/commonFunctions')
local testCasesForMenuIconMenuTitleParameters = require ('user_modules/shared_testcases/testCasesForMenuIconMenuTitleParameters')

--[[ Local Variables ]]
local empty_menuIcon
local icon_to_check
local absolute_path = testCasesForMenuIconMenuTitleParameters:ReadCmdLine("pwd")
local SGP_path = absolute_path .. "/SDL_bin/./".. "storage/" ..config.application1.registerAppInterfaceParams.appID.. "_" .. config.deviceMAC.. "/"
local SGP_path1 = absolute_path .. "/SDL_bin/".. "storage/" ..config.application1.registerAppInterfaceParams.appID.. "_" .. config.deviceMAC.. "/"


--[[ General Precondition before ATF start ]]
commonSteps:DeleteLogsFiles()
commonPreconditions:BackupFile("sdl_preloaded_pt.json")
commonPreconditions:BackupFile("smartDeviceLink.ini")

testCasesForPolicyTable:precondition_updatePolicy_AllowFunctionInHmiLeves({"BACKGROUND", "FULL", "LIMITED", "NONE"},"SetGlobalProperties")
testCasesForPolicyTable:precondition_updatePolicy_AllowFunctionInHmiLeves({"BACKGROUND", "FULL", "LIMITED", "NONE"},"ResetGlobalProperties")
empty_menuIcon, icon_to_check = testCasesForMenuIconMenuTitleParameters:UpdateINI("empty")

--[[ General Settings for configuration ]]
Test = require('connecttest')
require('user_modules/AppTypes')

--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")
function Test:Precondition_CheckINI_menuIcon()
  if (empty_menuIcon == true) then
    self:FailTestCase("menuIcon is not found in INI file.")
  end
end

function Test:Precondition_ActivateApp()
	testCasesForMenuIconMenuTitleParameters:ActivateAppDiffPolicyFlag(self, config.application1.registerAppInterfaceParams.appName, config.deviceMAC)
end

commonSteps:PutFile("Precondition_PutFile_action.png", "action.png")

function Test:Precondition_SetGlobalProperties_menuIcon()
  local cid = self.mobileSession:SendRPC("SetGlobalProperties",{ menuIcon = { value = "action.png", imageType = "DYNAMIC" } })

  EXPECT_HMICALL("UI.SetGlobalProperties", { menuIcon = { imageType = "DYNAMIC" } })--, value = SGP_path .. "action.png"} })
  :Do(function(_,data) self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {}) end)
  :ValidIf(function(_,data)
    if(data.params.menuIcon.value ~= nil) then
      if( (data.params.menuIcon.value == SGP_path .. "action.png") or (data.params.menuIcon.value == SGP_path1 .. "action.png") ) then
        return true
      else
        commonFunctions:printError("menuIcon.value is: " ..data.params.menuIcon.value ..". Expected: " .. SGP_path1 .. "action.png")
        return false
      end
    else
      commonFunctions:printError("menuIcon.value has a nil value")
      return false
    end
  end)

  EXPECT_HMICALL("TTS.SetGlobalProperties",{}):Times(0)
  EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS"})
  EXPECT_NOTIFICATION("OnHashChange")
end

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")

function Test:TestStep_menuIcon_empty_path_INI_PrecSGP()
  local cid = self.mobileSession:SendRPC("ResetGlobalProperties",{ properties = { "MENUICON" }})

  EXPECT_HMICALL("UI.SetGlobalProperties",{})
  :Do(function(_,data) self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {}) end)
  :ValidIf(function(_,data)
    if(data.params.menuIcon) then
      self:FailTestCase("menuIcon is sent within ResetGlobalProperties response. Expected: nil, Real: " ..data.params.menuIcon.value)
      return false
    else
      xmlReporter.AddMessage("EXPECT_HMIRESPONSE", {"EXPECTED_RESULT"}," menuIcon is nil")
      return true
    end
  end)

  EXPECT_HMICALL("TTS.SetGlobalProperties",{}):Times(0)
  EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS"})
  EXPECT_NOTIFICATION("OnHashChange")

end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")

function Test.Postcondition_RestoreConfigFiles()
  commonPreconditions:RestoreFile("smartDeviceLink.ini")
  commonPreconditions:RestoreFile("sdl_preloaded_pt.json")
end

function Test.Postcondition_StopSDL()
  StopSDL()
end

return Test