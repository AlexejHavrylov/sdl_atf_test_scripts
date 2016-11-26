---------------------------------------------------------------------------------------------
-- Requirement summary:
--    	[Policies]: User consent initiatation after Policy Table update

-- Description:
--     Local PT is successfully updated AND there are new application permissions that require User`s consent. App is in LIMITED.
--     1. Used preconditions:
--			  Activate application
--        Switch app to LIMITED
--
--     2. Performed steps
--		    Perform PTU with new permissions that require User consent
--
-- Expected result:
--  	Policies Manager must notify HMI about 'user-consent-required' via SDL.OnAppPermissionChanged{appID, appPermissionsConsentNeeded: true} per application in FULL,
--      that lacks the User`s permissions right after Policies Manager detects the user-unconsented permissions in Local PT
---------------------------------------------------------------------------------------------------------------------------
--[[ General Settings for configuration ]]
Test = require('connecttest')
require('cardinalities')

--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"

--[[ Required Shared libraries ]]
local commonFunctions = require ('user_modules/shared_testcases/commonFunctions')
local commonSteps = require('user_modules/shared_testcases/commonSteps')
require('user_modules/AppTypes')

--[[ Preconditions ]]
commonSteps:DeleteLogsFileAndPolicyTable()

function Test:Precondition_Activate_app()
  local RequestId = self.hmiConnection:SendRequest("SDL.ActivateApp", { appID = self.applications["Test Application"]})
  EXPECT_HMIRESPONSE(RequestId)
  :Do(function(_,data)
  if data.result.isSDLAllowed ~= true then
    local RequestIdGetMessage = self.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage", {language = "EN-US", messageCodes = {"DataConsent"}})
    EXPECT_HMIRESPONSE(RequestIdGetMessage)
    :Do(function()
    self.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality", {allowed = true, source = "GUI", device = {id = config.deviceMAC, name = "127.0.0.1"}})
    EXPECT_HMICALL("BasicCommunication.ActivateApp")
    :Do(function()
    self.hmiConnection:SendResponse(data.id,"BasicCommunication.ActivateApp", "SUCCESS", {})
    end)
    :Times(AnyNumber())
    end)
  end
  end)
  EXPECT_NOTIFICATION("OnHMIStatus", {hmiLevel = "FULL", systemContext = "MAIN"})
end

function Test:Precondition_Switch_app_to_LIMITED()
  self.hmiConnection:SendNotification("BasicCommunication.OnEventChanged",{isActive = true,eventName ="AUDIO_SOURCE"})
  self.mobileSession:ExpectNotification("OnHMIStatus",{hmiLevel ="LIMITED", systemContext = "MAIN"})
end  

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")

function Test:OnAppPermissionChanged_to_LIMITED_upon_PTU()
  local RequestIdGetURLS = self.hmiConnection:SendRequest("SDL.GetURLS", { service = 7 })
  EXPECT_HMIRESPONSE(RequestIdGetURLS,{result = {code = 0, method = "SDL.GetURLS", urls = {{url = "http://policies.telematics.ford.com/api/policies"}}}})
  :Do(function()
  self.hmiConnection:SendNotification("BasicCommunication.OnSystemRequest",
  {
    requestType = "PROPRIETARY",
    fileName = "filename"
  }
  )
  EXPECT_NOTIFICATION("OnSystemRequest", { requestType = "PROPRIETARY" })
  :Do(function()
  local CorIdSystemRequest = self.mobileSession:SendRPC("SystemRequest",
  {
    fileName = "PolicyTableUpdate",
    requestType = "PROPRIETARY"
  }, "files/PTU_NewPermissionsForUserConsent.json")
  local systemRequestId
  EXPECT_HMICALL("BasicCommunication.SystemRequest")
  :Do(function(_,data)
  systemRequestId = data.id
  self.hmiConnection:SendNotification("SDL.OnReceivedPolicyUpdate",
  {
    policyfile = "/tmp/fs/mp/images/ivsu_cache/PolicyTableUpdate"
  })
  local function to_run()
    self.hmiConnection:SendResponse(systemRequestId,"BasicCommunication.SystemRequest", "SUCCESS", {})
  end
  RUN_AFTER(to_run, 500)
  end)
  EXPECT_HMINOTIFICATION("SDL.OnAppPermissionChanged", {appID = self.HMIAppID, appPermissionsConsentNeeded = true })
  :Do(function()
  local RequestIdListOfPermissions = self.hmiConnection:SendRequest("SDL.GetListOfPermissions", { appID = self.HMIAppID })
  EXPECT_HMIRESPONSE(RequestIdListOfPermissions)
  :Do(function()
  local ReqIDGetUserFriendlyMessage = self.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage", {language = "EN-US", messageCodes = {"allowedFunctions"}})
  EXPECT_HMIRESPONSE(ReqIDGetUserFriendlyMessage)
  :Do(function()
  print("SDL.GetUserFriendlyMessage is received")
  end)
  end)
  self.mobileSession:ExpectResponse(CorIdSystemRequest, {success = true, resultCode = "SUCCESS"})
  end)
  end)
  end)
end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")

function Test.Postcondition_SDLForceStop()
  commonFunctions:SDLForceStop()
end