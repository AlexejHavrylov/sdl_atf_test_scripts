---------------------------------------------------------------------------------------------------
-- Item: Use Case: request is allowed by Policies
--
-- Requirement summary:
-- [SubscribeVehicleData] As a mobile app wants to send a request to subscribe for specified parameter
--
-- Description:
-- In case:
-- 1) hmi application sends valid SubscribeVehicleData to SDL and this request is allowed by Policies
-- SDL must:
-- Transfer this request to HMI and after successful response from hmi
-- Respond SUCCESS, success:true to mobile application
-- After HMI sends notification about changes in subcribed parameter
-- SDL must:
-- Forward this notification to mobile application


--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/VehicleData/commonVehicleData')

--[[ Local Variables ]]

local rpc1 = {
  name = "SubscribeVehicleData",
  params = {
    engineOilLife = true
  }
}

local rpc2 = {
  name = "OnVehicleData",
  params = {
    engineOilLife = 50.3
  }
}

local rpc3 = {
  name = "UnsubscribeVehicleData",
  params = {
    engineOilLife = true
  }
}

local function processRPCSubscribeSuccess(self)
  local mobileSession = common.getMobileSession(self, 1)
  local cid = mobileSession:SendRPC(rpc1.name, rpc1.params)
  EXPECT_HMICALL("VehicleInfo." .. rpc1.name, rpc1.params)
  :Do(function(_, data)
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {engineOilLife = {dataType = "VEHICLEDATA_ENGINEOILLIFE", resultCode = "SUCCESS"}})
    end)
  mobileSession:ExpectResponse(cid, { success = true, resultCode = "SUCCESS", engineOilLife = {dataType = "VEHICLEDATA_ENGINEOILLIFE", resultCode = "SUCCESS"} })
end

local function processRPCUnsubscribeSuccess(self)
  local mobileSession = common.getMobileSession(self, 1)
  local cid = mobileSession:SendRPC(rpc3.name, rpc3.params)
  EXPECT_HMICALL("VehicleInfo." .. rpc3.name, rpc3.params)
  :Do(function(_, data)
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {engineOilLife = {dataType = "VEHICLEDATA_ENGINEOILLIFE", resultCode = "SUCCESS"}})
    end)
  mobileSession:ExpectResponse(cid, { success = true, resultCode = "SUCCESS", engineOilLife = {dataType = "VEHICLEDATA_ENGINEOILLIFE", resultCode = "SUCCESS"} })
end


local function checkNotificationSuccess(self)
  local mobileSession = common.getMobileSession(self, 1)
  self.hmiConnection:SendNotification("VehicleInfo." .. rpc2.name, rpc2.params)
  --mobile side: expected OnVehicleData notification
  mobileSession:ExpectNotification("OnVehicleData", rpc2.params)
end

local function checkNotificationIgnored(self)
  local mobileSession = common.getMobileSession(self, 1)
  self.hmiConnection:SendNotification("VehicleInfo." .. rpc2.name, rpc2.params)
  --mobile side: OnVehicleData notification not expected
  mobileSession:ExpectNotification("OnVehicleData", rpc2.params):Times(0)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("RAI with PTU", common.registerAppWithPTU)
runner.Step("Activate App", common.activateApp)

runner.Title("Test")

runner.Step("RPC " .. rpc1.name, processRPCSubscribeSuccess)
runner.Step("RPC " .. rpc2.name .. " forwarded to mobile", checkNotificationSuccess)
runner.Step("RPC " .. rpc3.name, processRPCUnsubscribeSuccess)
runner.Step("RPC " .. rpc2.name .. " not forwarded to mobile", checkNotificationIgnored)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)