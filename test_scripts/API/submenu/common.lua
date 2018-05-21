---------------------------------------------------------------------------------------------------
-- Common module for my modules
---------------------------------------------------------------------------------------------------
 --[[ Required Shared libraries ]]
 --function addSubModule with menuIcon parameter
 
config.defaultProtocolVersion = 2

local actions = require("user_modules/sequences/actions")
local extra_actions = actions

function extra_actions.addSubMenu(pParams) 
local requestParams = {
    menuID = 1,
    menuName ="SubMenuName",
    position = 500
}

local requestUiParams = {
menuID = requestParams.menuID,
    menuParams = {
    menuName = requestParams.menuName,
    position = requestParams.position},
    appID = extra_actions.getHMIAppId()  
} 

local hmiConnection = extra_actions.getHMIConnection()
local mobSession = extra_actions.getMobileSession(pAppId)

local cid = mobSession:SendRPC("AddSubMenu",requestParams)
    EXPECT_HMICALL("UI.AddSubMenu", requestUiParams)
    :Do(function(_,data)
        hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
        mobSession:ExpectResponse(cid, { success = true, resultCode = "SUCCESS"}) 
        end)
    end 
return  extra_actions
