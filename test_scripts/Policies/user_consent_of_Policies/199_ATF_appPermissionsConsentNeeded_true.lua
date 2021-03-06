---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [Policies]: User consent required on permissions change
-- [Policies] GetListOfPermissions with appID
-- [HMI API] OnAppPermissionChanged notification
--
-- Description:
-- Local PT is successfully updated and there are new permissions that require User`s consent
-- 1. Used preconditions:
-- Unregister default application
-- Register application
-- Activate application
--
-- 2. Performed steps
-- Perform PTU with new permissions that require User consent
--
-- Expected result:
-- Policies Manager must notify HMI about 'user-consent-required' via SDL.OnAppPermissionChanged{appID, appPermissionsConsentNeeded:true,
-- provide the list of permissions that require User`s consent upon request from HMI via GetListOfPermissions(appID);
-- PoliciesManager must respond with the list of <groupName>s that have the field "user_consent_prompt" in corresponding <functional grouping> and
-- are assigned to the specified application (section "<appID>" -> "groups")
---------------------------------------------------------------------------------------------

--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"

--[[ Required Shared libraries ]]
local commonFunctions = require ('user_modules/shared_testcases/commonFunctions')
local commonSteps = require('user_modules/shared_testcases/commonSteps')
local testCasesForPolicyTable = require('user_modules/shared_testcases/testCasesForPolicyTable')

--[[ General Precondition before ATF start ]]
commonSteps:DeleteLogsFileAndPolicyTable()

--TODO(vvvakulenko): Should be removed when issue: "ATF does not stop HB timers by closing session and connection" is fixed
config.defaultProtocolVersion = 2

--[[ General Settings for configuration ]]
Test = require('connecttest')
require('cardinalities')
require('user_modules/AppTypes')

--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")
function Test:Precondition_Activate_app()
  testCasesForPolicyTable:trigger_getting_device_consent(self, config.application1.registerAppInterfaceParams.appName, config.deviceMAC)
end

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")
function Test:TestStep_PTU_appPermissionsConsentNeeded_true()

  local RequestIdGetURLS = self.hmiConnection:SendRequest("SDL.GetURLS", { service = 7 })
  EXPECT_HMIRESPONSE(RequestIdGetURLS,{result = {code = 0, method = "SDL.GetURLS", urls = {{url = "http://policies.telematics.ford.com/api/policies"}}}})
  :Do(function(_,_)
      EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate", {status = "UPDATING"}, {status = "UP_TO_DATE"}):Times(2)
      :Do(function(_,data)
          if(data.params.status == "UP_TO_DATE") then

            EXPECT_HMINOTIFICATION("SDL.OnAppPermissionChanged",
              {appID = self.applications[config.application1.registerAppInterfaceParams.appName], appPermissionsConsentNeeded = true })
            :Do(function(_,_)
                local RequestIdListOfPermissions = self.hmiConnection:SendRequest("SDL.GetListOfPermissions",
                  { appID = self.applications[config.application1.registerAppInterfaceParams.appName] })

                EXPECT_HMIRESPONSE(RequestIdListOfPermissions)
                :Do(function(_,data1)
                    local groups = {}
                    if #data1.result.allowedFunctions > 0 then
                      for i = 1, #data1.result.allowedFunctions do
                        groups[i] = {
                          name = data1.result.allowedFunctions[i].name,
                          id = data1.result.allowedFunctions[i].id,
                          allowed = true}
                      end
                    end

                    self.hmiConnection:SendNotification("SDL.OnAppPermissionConsent", { appID = self.applications[config.application1.registerAppInterfaceParams.appName], consentedFunctions = groups, source = "GUI"})
                    EXPECT_NOTIFICATION("OnPermissionsChange")
                  end)
              end)
          end
        end)
      self.hmiConnection:SendNotification("BasicCommunication.OnSystemRequest", { requestType = "PROPRIETARY", fileName = "filename"})

      EXPECT_NOTIFICATION("OnSystemRequest", { requestType = "PROPRIETARY" })
      :Do(function(_,_)

          self.mobileSession:SendRPC("SystemRequest", { fileName = "PolicyTableUpdate", requestType = "PROPRIETARY"}, "files/PTU_NewPermissionsForUserConsent.json")

          local systemRequestId
          EXPECT_HMICALL("BasicCommunication.SystemRequest")
          :Do(function(_,data)
              systemRequestId = data.id
              self.hmiConnection:SendNotification("SDL.OnReceivedPolicyUpdate", { policyfile = "/tmp/fs/mp/images/ivsu_cache/PolicyTableUpdate"})

              local function to_run()
                self.hmiConnection:SendResponse(systemRequestId,"BasicCommunication.SystemRequest", "SUCCESS", {})
              end
              RUN_AFTER(to_run, 500)
            end)

        end)
    end)
end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")
function Test.Postcondition_StopSDL()
  StopSDL()
end

return Test
