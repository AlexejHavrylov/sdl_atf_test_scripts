
-- 1)starting of SDL
-- 2)initialization of HMI  
-- 3)connect mobile 
-- 4)register mobile application
-- 5)activate application
-- 6)application sends valid AddSubMenu request and gets UI.AddSubMenu "SUCCESS" response from HMI, 
-- 7)SDL must respond with (resultCode: SUCCESS, success:true) to mobile application.

local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/submenu/commonMyScripts')  

runner.testSettings.isSelfIncluded = false
local actions = require("user_modules/sequences/actions")


local menuIcon ={
syncFileName ="icon.png",
fileType ="GRAPHIC_PNG",
persistentFile =false,
systemFile = false,
offset =0,
length =11600
}
 
local sourceParam = 
    {menuID = 1,
    menuName ="SubMenuName",
    position = 500
}



function addSubMenu(pParams)
    requestParams = sourceParam    
    local requestUiParams = {
    menuID = requestParams.menuID,
        menuParams = {
        menuName = requestParams.menuName,
        position = requestParams.position},
        appID = actions.getHMIAppId()
}

    if  pParams ~=nil then
        requestParams.menuIcon = pParams
        requestUiParams.menuIcon = pParams
    

    end


-- requestUiParams.menuIcon = pParams

local mobSession =actions.getMobileSession(pAppId)
local hmiConnection = actions.getHMIConnection()
local cid = mobSession:SendRPC("AddSubMenu",requestParams)
    EXPECT_HMICALL("UI.AddSubMenu", requestUiParams)    :Do(function(_,data)
        hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
        mobSession:ExpectResponse(cid, { success = true, resultCode = "SUCCESS"}) 
        end)
end 


runner.Step("Precondition",common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session",common.start)
runner.Step("Register App", common.registerApp) 
runner.Step("Activate App", common.activateApp)

runner.Title("Test")
runner.Step("Add Sub Menu with menuIcon",addSubMenu)

runner.Step("Stop SDL", common.postconditions)
