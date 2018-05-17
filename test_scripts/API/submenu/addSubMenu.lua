
-- 1)starting of SDL
-- 2)initialization of HMI  
-- 3)connect mobile 
-- 4)register mobile application
-- 5)activate application
-- 6)application sends valid AddSubMenu request and gets UI.AddSubMenu "SUCCESS" response from HMI, 
-- 7)SDL must respond with (resultCode: SUCCESS, success:true) to mobile application.

local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/submenucommonMyScripts')  

runner.testSettings.isSelfIncluded = false

runner.Step("Precondition",common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session",common.start)
runner.Step("Register App", common.registerApp) 
runner.Step("Activate App", common.activateApp)
runner.Step("Add Sub Menu with menuIc",common.addSubMenu)
runner.Step("Stop SDL", common.postconditions)
