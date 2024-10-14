local basalt = require("basalt")

-- Initialize ME Bridge peripheral
local me = peripheral.find("meBridge")
local mon = peripheral.find("monitor")
local geo = peripheral.find("geoScanner")

local main
local crafting = false

local function comma_value(n) -- credit http://richard.warburton.it
    local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
    return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

local function allFalse(t)
    for _, v in pairs(t) do
        if not v.isBusy == false then return false end
    end

    return true
end

-- Check for monitor
if mon then
    main = basalt.addMonitor()
        :setMonitor(mon)
else
    main = basalt.addFrame()
end

main:setBackground(colors.black)

main:addButton()
    :setPosition(1, 1)
    :setSize(5, 1)
    :setText("Reset")
    :onClick(function()
        os.queueEvent("reset_click")
    end)

--#region UI Elements
-- TODO: Use flexbox
-- Storage stats frame
local storageFrame = main:addFrame()
    :setPosition(2, 2)
    :setSize("parent.w - 2", 5)
    :setBorder(colors.white)
    :setBackground(colors.black)
storageFrame:addLabel()
    :setPosition(1, 1)
    :setSize(7, 1)
    :setText("Storage")
    :setForeground(colors.lightBlue)
storageFrame.storageBar = storageFrame:addProgressbar()
    :setPosition(2, 3)
    :setSize("parent.w - 2", 1)
    :setBackground(colors.gray)
    :setProgressBar(colors.green)
storageFrame.storageLabel = storageFrame:addLabel()
    :setPosition(2, 2)
    :setSize(8, 1)
    :setForeground(colors.white)
    :setBackground(colors.black)

-- CPU stats frame
local cpuFrame = main:addFrame()
    :setPosition(2, 12)
    :setSize("parent.w - 2", 12)
    :setBorder(colors.white)
    :setBackground(colors.black)
cpuFrame:addLabel()
    :setPosition(1, 1)
    :setSize(4, 1)
    :setText("CPUs")
    :setForeground(colors.lightBlue)
cpuFrame.cpuBar = cpuFrame:addProgressbar()
    :setPosition(2, 3)
    :setSize("parent.w - 2", 1)
    :setBackground(colors.gray)
    :setProgressBar(colors.green)
cpuFrame.cpuLabel = cpuFrame:addLabel()
    :setPosition(2, 4)
    :setSize("parent.w - 2", 1)
    :setForeground(colors.white)
    :setBackground(colors.black)

-- Energy usage frame
local energyFrame = main:addFrame()
    :setPosition(2, 8)
    :setSize("(parent.w / 2) - 2", 3)
    :setBorder(colors.white)
    :setBackground(colors.black)
energyFrame:addLabel()
    :setPosition(1, 1)
    :setSize(12, 1)
    :setText("Energy Usage")
    :setForeground(colors.lightBlue)
energyFrame.energyLabel = energyFrame:addLabel()
    :setPosition(2, 2)
    :setSize("parent.w - 2", 1)
    :setForeground(colors.white)
    :setBackground(colors.black)

-- Channel usage frame
local channelFrame = main:addFrame()
    :setPosition(energyFrame:getPosition() + 25, 8)
    :setSize("(parent.w / 2) - 2", 3)
    :setBorder(colors.white)
    :setBackground(colors.black)
channelFrame:addLabel()
    :setPosition(1, 1)
    :setSize(13, 1)
    :setText("Channel Usage")
    :setForeground(colors.lightBlue)
channelFrame.channelLabel = channelFrame:addLabel()
    :setPosition(2, 2)
    :setSize("parent.w - 2", 1)
    :setForeground(colors.white)
    :setBackground(colors.black)

-- Crafting indicator label - change to something more visually appealing? get item icon?
local isCraftingIndicator = main:addLabel()
    :setPosition(8, 1)
    :setZIndex(10)
    :setSize("parent.w - 2", 1)
    :setForeground(colors.red)
--#endregion

--#region Update functions
local function updateStorageStats()
    local storageAvailable = me.getAvailableItemStorage()
    local totalStorage = me.getTotalItemStorage()
    local storageTaken
    local storagePercentage
    if totalStorage ~= nil and storageAvailable ~= nil then
        storageTaken = tonumber(totalStorage) - tonumber(storageAvailable)
        storagePercentage = (storageTaken / totalStorage) * 100
    end

    -- Only update and queue event if the percentage has changed
    if storagePercentage ~= basalt.getVariable("storagePercentage") and storagePercentage ~= nil then
        basalt.setVariable("storagePercentage", storagePercentage)
        os.queueEvent("storage_updated")
    end
end

local function updateCPUStats()
    local cpus = me.getCraftingCPUs()
    local totalCPUs = 0
    local busyCPUs = 0
    local totalBytes = 0
    local bytesUsed = 0

    if cpus ~= nil then
        totalCPUs = #cpus
        for _, cpu in ipairs(cpus) do
            totalBytes = totalBytes + cpu.storage
            if cpu.isBusy then
                bytesUsed = bytesUsed + cpu.storage
                busyCPUs = busyCPUs + 1
                crafting = true
            end
        end
        if allFalse(cpus) then -- if all cpus are idle, set crafting to false
            crafting = false
        end
    end

    local cpuUsage = (busyCPUs / totalCPUs) * 100
    if cpuUsage ~= basalt.getVariable("cpuUsage") and cpuUsage ~= nil then
        basalt.setVariable("cpuUsage", (busyCPUs / totalCPUs) * 100)
        basalt.setVariable("cpuStats", string.format("%s/%s", comma_value(busyCPUs), comma_value(totalCPUs)))
        basalt.setVariable("cpuBytes", string.format("%s/%s", comma_value(bytesUsed), comma_value(totalBytes)))
        os.queueEvent("cpu_updated")
    end
end

local function updateEnergyUsage()
    local energy = me.getEnergyUsage()
    if energy ~= nil then
        if energy ~= basalt.getVariable("energyUsage") and energy ~= nil then
            local formatted_num = string.format("%.2f FE/t", energy * 2)
            basalt.setVariable("energyUsage", comma_value(formatted_num))
            os.queueEvent("energy_updated")
        end
    end
end

local function updateChannelUsage()
    if type(me.getUsedChannels) ~= "function" then
        channelFrame.channelLabel:setText("Check README!")
        return
    end

    local channels = me.getUsedChannels()
    local maxChannels = 0
    -- local scan = geo.scan(10) -- Remove until determine performance impact
    
    -- if scan ~= nil then
        
    --     for k,v in ipairs(scan) do
    --         if v.name == "ae2:controller" then
    --             maxChannels = maxChannels + 32
    --             basalt.setVariable("maxChannels", maxChannels)
    --         end
    --     end
    -- end

    if channels ~= basalt.getVariable("channelUsage") and channels ~= nil then
        basalt.setVariable("channelUsage", channels)
        -- basalt.setVariable("maxChannels", maxChannels)
        os.queueEvent("channels_updated")
    end
end

local function updateCraftingStatus()
    if crafting then
        local items = me.listCraftableItems()

        for k,v in ipairs(items) do
            if me.isItemCrafting(v) then
                isCraftingIndicator:setText("Crafting: " .. v.displayName)
            end
        end
    else
        isCraftingIndicator:setText("")
    end

end
--#endregion

--#region Event handlers
storageFrame:onEvent("storage_updated", function()
    local storagePercentage = basalt.getVariable("storagePercentage")
    if storagePercentage == nil then return end

    storageFrame.storageBar:setProgress(storagePercentage)

    if storagePercentage >= 80 then
        storageFrame.storageBar:setProgressBar(colors.red)
    elseif storagePercentage >= 50 then
        storageFrame.storageBar:setProgressBar(colors.yellow)
    else
        storageFrame.storageBar:setProgressBar(colors.green)
    end

    storageFrame.storageLabel:setText(string.format("%.2f%%", storagePercentage))
end)

cpuFrame:onEvent("cpu_updated", function()
    local cpuUsage = basalt.getVariable("cpuUsage")
    local cpuStats = basalt.getVariable("cpuStats")
    local cpuBytes = basalt.getVariable("cpuBytes")

    if cpuUsage == nil then return end

    cpuFrame.cpuBar:setProgress(cpuUsage)
    if cpuUsage >= 80 then
        cpuFrame.cpuBar:setProgressBar(colors.red)
    elseif cpuUsage >= 50 then
        cpuFrame.cpuBar:setProgressBar(colors.yellow)
    else
        cpuFrame.cpuBar:setProgressBar(colors.green)
    end

    cpuFrame.cpuLabel:setText("CPUs: " .. cpuStats .. " " .. "Bytes: " .. cpuBytes)
end)

energyFrame:onEvent("energy_updated", function()
    local energyUsage = basalt.getVariable("energyUsage")
    if energyUsage == nil then return end

    energyFrame.energyLabel:setText(energyUsage)
end)

channelFrame:onEvent("channels_updated", function ()
    local channelUsage = basalt.getVariable("channelUsage")
    if channelUsage == nil then return end
    -- if channelUsage == nil or maxChannels == nil then return end
    -- local maxChannels = basalt.getVariable("maxChannels")
    -- channelFrame.channelLabel:setText(string.format("%d/%d", channelUsage, maxChannels))
    channelFrame.channelLabel:setText(string.format("%d", channelUsage))
end)
--#endregion

-- Update loop
local function updateAll()
    updateStorageStats()
    updateCPUStats()
    updateEnergyUsage()
    updateChannelUsage()
    updateCraftingStatus()
end

-- Set up a timer to trigger updates
local function setupUpdateTimer()
    updateAll()
    os.startTimer(1) -- Wait for 1 second
end

-- Event handler for the update timer
main:onEvent(function (...)
    local args = {...} -- basalt event system is weird, need this to specify event
    
    if args[2] == "timer" then -- TODO: specify which timer
        setupUpdateTimer()
    elseif args[2] == "reset_click" then -- temporary, used for quickly testing ui changes - add to menu for user debug usage?
        shell.run("reboot")
    end
end)

-- Initial timer setup
setupUpdateTimer()

-- Start the application
basalt.autoUpdate()