local CloudProvider = require("cloudproviders")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")


local function ftpInfo()
    print("info FTP")
end

local function ftpConfig(something, callback)
    print("config FTP")
    if type(callback) == "function" then
        print("executing callback")
        callback()
    end
end

local function ftpEdit(item)
    print("edit FTP item", item)
    for k, v in pairs(item) do
        print(k,v)
    end
end


local FTPProvider = WidgetContainer:new{
    name = "ftp",
    is_doc_only = false,
}

function FTPProvider:init()
    CloudProvider:registerProvider("ftp", {
        name = _("FTP"),
        sync = false,
        list = function()
        end,
        download = function()
        end,
        config = ftpConfig,
        edit = ftpEdit,
        info = ftpInfo,
    })
end

return FTPProvider
