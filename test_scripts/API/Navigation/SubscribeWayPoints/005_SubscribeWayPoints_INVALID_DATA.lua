---------------------------------------------------------------------------------------------------
-- User story: https://github.com/smartdevicelink/sdl_requirements/issues/26
-- Use case: https://github.com/smartdevicelink/sdl_requirements/blob/master/detailed_docs/embedded_navi/Subscribe_to_Destination_and_Waypoints.md
-- Item: Use Case 1: Subscribe to Destination & Waypoints: Alternative flow 1: Request is invalid
--
-- Requirement summary:
-- [SubscribeWayPoints] As a mobile app I want to be able to subscribe on notifications about
-- any changes to the destination or waypoints.
--
-- Description:
-- In case:
-- 1) Request is invalid
--
-- SDL must:
-- 1) SDL responds INVALID_DATA, success:false to mobile application and doesn't subscribe on destination and waypoints change notifications

---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/Navigation/commonNavigation')

--[[ Local Functions ]]
local function invalidJson(self)
  local params = { "/   // "}
  local cid = self.mobileSession1:SendRPC("SubscribeWayPoints", params)
  EXPECT_HMICALL("Navigation.SubscribeWayPoints"):Times(0)

  self.mobileSession1:ExpectResponse(cid, { success = false, resultCode = "INVALID_DATA" })
  common:DelayedExp()
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("RAI, PTU", common.registerAppWithPTU)
runner.Step("Activate App", common.activateApp)

runner.Title("Test")
runner.Step("SubscribeWayPoints invalid json", invalidJson)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)