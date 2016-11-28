---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [Policies]: User consent storage in LocalPT (OnAppPermissionConsent without appID)
-- [HMI API] OnAppPermissionConsent notification
--
-- Description:
-- 1. Used preconditions:
-- SDL and HMI are running
-- <Device> is connected to SDL and consented by the User, <App> is running on that device.
-- <App> is registered with SDL and is present in HMI list of registered aps.
-- Local PT has permissions for <App> that require User`s consent
-- 2. Performed steps: Activate App
--
-- Expected result:
-- 1. HMI->SDL: SDL.ActivateApp {appID}
-- 2. SDL->HMI: SDL.ActivateApp_response{isPermissionsConsentNeeded: true, params}
-- 3. HMI->SDL: GetUserFriendlyMessage{params},
-- 4. SDL->HMI: GetUserFriendlyMessage_response{params}
-- 5. HMI->SDL: GetListOfPermissions{appID}
-- 6. SDL->HMI: GetListOfPermissions_response{}
-- 7. HMI: display the 'app permissions consent' message.
-- 8. The User allows or disallows definite permissions.
-- 9. HMI->SDL: OnAppPermissionConsent {params}
-- 10. PoliciesManager: update "<appID>" subsection of "user_consent_records" subsection of "<device_identifier>" section of "device_data" section in Local PT
---------------------------------------------------------------------------------------------
--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"

--[[ Required Shared libraries ]]
local commonFunctions = require ('user_modules/shared_testcases/commonFunctions')
local commonSteps = require('user_modules/shared_testcases/commonSteps')
local testCasesForPolicyTableSnapshot = require('user_modules/shared_testcases/testCasesForPolicyTableSnapshot')
local testCasesForPolicyTable = require('user_modules/shared_testcases/testCasesForPolicyTable')

--[[ Local variables ]]
local ServerAddress = commonFunctions:read_parameter_from_smart_device_link_ini("ServerAddress")
testCasesForPolicyTable:Precondition_updatePolicy_By_overwriting_preloaded_pt("files/jsons/Policy/Related_HMI_API/OnAppPermissionConsent.json")

--[[ General Precondition before ATF start ]]
commonSteps:DeleteLogsFileAndPolicyTable()

--[[ General Settings for configuration ]]
Test = require('connecttest')
require('cardinalities')
require('user_modules/AppTypes')

--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")

function Test:TestStep_User_consent_on_activate_app()
  local is_test_fail
  local RequestId = self.hmiConnection:SendRequest("SDL.ActivateApp", { appID = self.applications[config.application1.registerAppInterfaceParams.appName]})

  EXPECT_HMIRESPONSE(RequestId)
  :Do(function(_,_)

      local RequestId1 = self.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage", {language = "EN-US", messageCodes = {"DataConsent"}})
      --hmi side: expect SDL.GetUserFriendlyMessage message response
      EXPECT_HMIRESPONSE( RequestId1, {result = {code = 0, method = "SDL.GetUserFriendlyMessage"}})
      :Do(function(_,_)
          self.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality",
            {allowed = true, source = "GUI", device = {id = config.deviceMAC, name = ServerAddress, isSDLAllowed = true}})

          local request_id_list_of_permissions = self.hmiConnection:SendRequest("SDL.GetListOfPermissions", { appID = self.applications[config.application1.registerAppInterfaceParams.appName] })
          EXPECT_HMIRESPONSE(request_id_list_of_permissions)
          :Do(function(_,data)
              local groups = {}
              if #data.result.allowedFunctions > 0 then
                for i = 1, #data.result.allowedFunctions do
                  groups[i] = data.result.allowedFunctions[i]
                end
              end

              self.hmiConnection:SendNotification("SDL.OnAppPermissionConsent", { consentedFunctions = groups, source = "GUI"})
              EXPECT_NOTIFICATION("OnPermissionsChange")
              :Do(function(_,_)
                  testCasesForPolicyTableSnapshot:extract_pts({self.applications[config.application1.registerAppInterfaceParams.appName]})
                  local app_consent_location = testCasesForPolicyTableSnapshot:get_data_from_PTS("device_data."..config.deviceMAC..".user_consent_records."..config.application1.registerAppInterfaceParams.appID..".consent_groups.Location")
                  local app_consent_notifications = testCasesForPolicyTableSnapshot:get_data_from_PTS("device_data."..config.deviceMAC..".user_consent_records."..config.application1.registerAppInterfaceParams.appID..".consent_groups.Notifications")
                  local app_consent_Base4 = testCasesForPolicyTableSnapshot:get_data_from_PTS("device_data."..config.deviceMAC..".user_consent_records."..config.application1.registerAppInterfaceParams.appID..".consent_groups.Base-4")

                  if(app_consent_location ~= true) then
                    commonFunctions:printError("Error: consent_groups.Location function for appID should be true")
                    is_test_fail = true
                  end

                  if(app_consent_notifications ~= true) then
                    commonFunctions:printError("Error: consent_groups.Notifications function for appID should be true")
                    is_test_fail = true
                  end

                  if(app_consent_Base4 ~= false) then
                    commonFunctions:printError("Error: consent_groups.Notifications function for appID should be false")
                    is_test_fail = true
                  end

                end)
            end)

        end)
    end)

  EXPECT_HMICALL("BasicCommunication.ActivateApp")
  :Do(function(_,data) self.hmiConnection:SendResponse(data.id,"BasicCommunication.ActivateApp", "SUCCESS", {}) end)

  EXPECT_NOTIFICATION("OnHMIStatus", {hmiLevel = "FULL", systemContext = "MAIN"})

  if(is_test_fail == true) then
    self:FailTestCase("Test is FAILED. See prints.")
  end
end

function Test.TestStep_check_LocalPT_for_updates()
  return true
end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")
function Test.Postcondition_Restore_PreloadedPT()
  testCasesForPolicyTable:Restore_preloaded_pt()
end

function Test.Postcondition_SDLForceStop()
  commonFunctions:SDLForceStop()
end

return Test
