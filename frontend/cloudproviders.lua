local ButtonDialog = require("ui/widget/buttondialog")
local ButtonDialogTitle = require("ui/widget/buttondialogtitle")
local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local Menu = require("ui/widget/menu")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")

local logger = require("logger")
local dump = require("dump")
local _ = require("gettext")

local CloudProvider = Menu:extend{
    --initialized = false,
    no_title = false,
    show_parent = nil,
    is_popout = false,
    is_borderless = true,
    title = _("Cloud storage"),
    
    cloud_servers = {
        {
            text = _("Add new cloud storage"),
            title = _("Choose cloud type"),
            url = "add",
            editable = false,
        },
    },
}

local providers = {}
local providers_menu = {}

function CloudProvider:init()
    logger.warn("Starting cloud provider")
    
    --if CloudProvider.initialized then
    --    logger.info("already initialized")
    --    return
    --end
    
    
    logger.warn("setup menu")
    
    self.cs_settings = self:readSettings()
    self.show_parent = self
    if self.item then
        self.item_table = self:genItemTable(self.item)
        self.choose_folder_mode = true
    else
        self.item_table = self:genItemTableFromRoot()
    end
    self.width = Screen:getWidth()
    self.height = Screen:getHeight()
    Menu.init(self)
    if self.item then
        self.item_table[1].callback()
    end
    
    --CloudProvider.initialized = true
end

function CloudProvider:readSettings()
    self.cs_settings = LuaSettings:open(DataStorage:getSettingsDir().."/cloudstorage.lua")
    return self.cs_settings
end

function CloudProvider:onReturn()
    if #self.paths > 0 then
        table.remove(self.paths)
        local path = self.paths[#self.paths]
        if path then
            -- return to last path
            self:openCloudServer(path.url)
        else
            -- return to root path
            self:init()
        end
    end
    return true
end

function CloudProvider:genItemTable(item)
    local item_table = {}
    local added_servers = self.cs_settings:readSetting("cs_servers") or {}
    for _, server in ipairs(added_servers) do
        if server.name == item.text and server.password == item.password and server.type == item.type then
            table.insert(item_table, {
                text = server.name,
                address = server.address,
                username = server.username,
                password = server.password,
                type = server.type,
                url = server.url,
                callback = function()
                    self.type = server.type
                    self.password = server.password
                    self.address = server.address
                    self.username = server.username
                    self:openCloudServer(server.url)
                end,
            })
        end
    end
    return item_table
end

function CloudProvider:genItemTableFromRoot()
    local item_table = {}
    table.insert(item_table, {
        text = _("Add new cloud storage"),
        callback = function()
            self:selectCloudType()
        end,
    })
    local added_servers = self.cs_settings:readSetting("cs_servers") or {}
    for _, server in ipairs(added_servers) do
        table.insert(item_table, {
            text = server.name,
            address = server.address,
            username = server.username,
            password = server.password,
            type = server.type,
            editable = true,
            url = server.url,
            sync_source_folder = server.sync_source_folder,
            sync_dest_folder = server.sync_dest_folder,
            callback = function()
                self.type = server.type
                self.password = server.password
                self.address = server.address
                self.username = server.username
                self:openCloudServer(server.url)
            end,
        })
    end
    return item_table
end

function CloudProvider:selectCloudType()
    local buttons = {}
    for _, v in ipairs(providers_menu) do
        local row = {}
        row[1] = {
            text = providers[v].name,
            callback = function()
                UIManager:close(self.cloud_dialog)
                self:configCloud(v)
            end,
        }
        buttons[#buttons + 1] = row
    end
    
    self.cloud_dialog = ButtonDialogTitle:new{
            title = _("Choose cloud storage type"),
            title_align = "center",
            buttons = buttons,
    }

    UIManager:show(self.cloud_dialog)
    return true
end

function CloudProvider:configCloud(provider)
    if not providers[provider] then
        logger.warn("No valid provider", provider)
        return
    end
    local callbackAdd = function(fields)
        if type(fields) == "table" then
            for i, v in ipairs(fields) do
                print("callback", i, v)
            end
        else
            print("callback", fields)
        end
    end
    providers[provider].config(nil, callbackAdd)
end

function CloudProvider:onMenuHold(item)
    if item.type == "folder_long_press" then
        local title = T(_("Select this directory?\n\n%1"), BD.dirpath(item.url))
        local onConfirm = self.onConfirm
        local button_dialog
        button_dialog = ButtonDialogTitle:new{
            title = title,
            buttons = {
                {
                    {
                        text = _("Cancel"),
                        callback = function()
                            UIManager:close(button_dialog)
                        end,
                    },
                    {
                        text = _("Select"),
                        callback = function()
                            if onConfirm then
                                onConfirm(item.url)
                            end
                            UIManager:close(button_dialog)
                            UIManager:close(self)
                        end,
                    },
                },
            },
        }
        UIManager:show(button_dialog)
    end
    if item.editable then
        local cs_server_dialog
        local buttons = {
            {
                {
                    text = _("Info"),
                    enabled = true,
                    callback = function()
                        UIManager:close(cs_server_dialog)
                        providers[item.type].info()
                    end
                },
                {
                    text = _("Edit"),
                    enabled = true,
                    callback = function()
                        UIManager:close(cs_server_dialog)
                        providers[item.type].edit(item)
                        --self:editCloudServer(item)

                    end
                },
                {
                    text = _("Delete"),
                    enabled = true,
                    callback = function()
                        UIManager:close(cs_server_dialog)
                        self:deleteCloudServer(item)
                    end
                },
            },
        }
        if item.type == "dropbox" then
            table.insert(buttons, {
                {
                    text = _("Synchronize now"),
                    enabled = item.sync_source_folder ~= nil and item.sync_dest_folder ~= nil,
                    callback = function()
                        UIManager:close(cs_server_dialog)
                        self:synchronizeCloud(item)
                    end
                },
                {
                    text = _("Synchronize settings"),
                    enabled = true,
                    callback = function()
                        UIManager:close(cs_server_dialog)
                        self:synchronizeSettings(item)
                    end
                },
            })
        end
        cs_server_dialog = ButtonDialog:new{
            buttons = buttons
        }
        UIManager:show(cs_server_dialog)
        return true
    end
end


function CloudProvider:onMenuSelect(item)
    if item.callback then
        if item.url ~= nil then
            table.insert(self.paths, {
                url = item.url,
            })
        end
        item.callback()
    elseif item.type == "file" then
        self:downloadFile(item)
    elseif item.type == "other" then
        return true
    else
        table.insert(self.paths, {
            url = item.url,
        })
        if not self:openCloudServer(item.url) then
            table.remove(self.paths)
        end
    end
    return true
end

function CloudProvider:registerProvider(name, value)
    if providers[name] == nil then
        providers[name] = value
        table.insert(providers_menu, name)
    end
    return true
end

function CloudProvider:dump(t)
    if t then
        print(dump(t))
    else
        print(dump(providers), "\n", dump(providers_menu))
    end
end


function CloudProvider:getMenuTable()
    local buttons = {}
    for _, k in ipairs(providers_menu) do
        local entry = {
            text = k,
            callback = function()
                providers[k].download()
            end,
        }
        buttons[#buttons + 1] = entry
    end
    return buttons
end

function CloudProvider:getMainMenuTable()
    self:init()
    return {
        text = _("Cloud providers"),
        callback = function()
            local cloud = self.menu:new{}
            UIManager:show(cloud)
            local filemanagerRefresh = function() self.menu.ui:onRefresh() end
            function cloud:onClose()
                filemanagerRefresh()
                UIManager:close(cloud)
            end
        end,
    }
end

function CloudProvider:isReady()
    return #providers_menu >= 1
end

return CloudProvider

--[[
CloudProviders:registerProvider("dropbox", {
    name = _("Dropbox"),
    sync = true,
    list = function()
    end,
    download = function()
    end,
})

CloudProviders:registerProvider("ftp", {
    name = _("FTP"),
    sync = false,
    list = function()
    end,
    download = function()
    end,
})

CloudProviders:dump()
CloudProviders:dump(CloudProviders:getMenuTable())


]]
