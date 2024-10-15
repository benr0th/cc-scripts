local utils = require("/todolist/gistUtils")
local saveUtils = require("/todolist/saveUtils")
local basalt

-- Try to require the Basalt library
local success, err = pcall(function()
    return require("basalt")
end)

if success then
    basalt = err  -- If successful, assign the Basalt variable
else
    print("Basalt is not installed. Attempting to install...")
    
    -- Attempt to run the installation script
    local installSuccess, installErr = pcall(function()
        shell.run("wget run https://basalt.madefor.cc/install.lua packed todolist/basalt.lua master")
    end)

    if installSuccess then
        print("Basalt installed successfully.")
        basalt = require("basalt")  -- Require again after installation
    else
        print("Failed to install Basalt: " .. installErr)
        return  -- Exit the program if installation fails
    end
end

local main
local mon = peripheral.find("monitor")

-- Check for monitor
if mon then
    main = basalt.addMonitor()
        :setMonitor(mon)
else
    main = basalt.addFrame()
end

if main == nil then basalt.debug("Error: No frame found") shell.run("terminate") end

main:setBackground(colors.black)

local tasksData = readTasks()

local makeTaskList

-- Main flexbox container
local flex = main:addFlexbox()
    :setWrap("nowrap")
    :setBackground(colors.black)
    :setPosition(2, 2)
    :setSize("parent.w - 2", "parent.h - 2")
    :setDirection("vertical")

local function addTask()
    if main:getChild("inputFrame") then return end
    local inputFrame = main:addFrame("inputFrame")
        :setBackground(colors.gray)
        :setSize("parent.w - 12", 1)
        :setPosition(12, 2)

    local taskInput = inputFrame:addInput("taskInput")
        :setInputType("text")
        :setDefaultText("Click me, F1 to cancel")
        :setInputLimit(30)
        :setBackground(colors.gray)
        :setForeground(colors.white)
        :setSize("parent.w", 1)
        :setPosition(1, 1)
        :setFocus(true)
        :onKey(function (self,event,key)
            if key == keys.enter or key == keys.numPadEnter then
                local val = self.getValue()
                if val ~= "" then
                    table.insert(tasksData, 1, val)
                    writeTasks(tasksData)
                    makeTaskList()
                    main:removeChild("inputFrame")  -- Remove input field after task is added
                end
            elseif key == keys.f1 then
                main:removeChild("inputFrame")
            end
        end)

end

local addTaskButton = flex:addButton()
    :setPosition(1, 1)
    :setSize(8, 1)
    :setText("Add Task")
    :setBackground(colors.black)
    :setForeground(colors.white)
    :onClick(addTask)

local taskFrame = flex:addScrollableFrame()
    :setBackground(colors.black)
    :setBorder(colors.white)
    :setPosition(1, 1)  -- Adjust position to avoid overlapping with the button
    :setSize("parent.w", "parent.h - 2")  -- Leave space for the button
    :setDirection("vertical")

local scrollBar = main:addScrollbar("scrollBar"):setPosition("parent.w", 4):setSize(1, 15):setScrollAmount(#tasksData - 2):onChange(function (self, _, value)
    taskFrame:setOffset(0, value-1)
end)

makeTaskList = function()
    if tasksData == nil then return end

    taskFrame:removeChildren()  -- Clear existing children before repopulating
    main:removeChild("scrollBar")
    scrollBar = main:addScrollbar("scrollBar"):setPosition("parent.w", 4):setSize(1, 15):setScrollAmount(#tasksData - 3):onChange(function (self, _, value)
        taskFrame:setOffset(0, value-1)
    end)

    for i, task in ipairs(tasksData) do
        -- Add a checkbox for each task
        taskFrame:addCheckbox()
            :setPosition(2, i * 2)         -- Space items properly
            :onChange(function()
                table.remove(tasksData, i) -- Remove the task
                writeTasks(tasksData)      -- Save the updated task list
                makeTaskList()             -- Refresh the list after removal
            end)
        
        -- Add a label for each task
        taskFrame:addLabel()
            :setText(task)
            :setForeground(colors.white)
            :setPosition(4, i * 2)  -- Position next to the checkbox
    end
end

-- Initialize the task list
makeTaskList()

local function restart(self, event, key)
    if key == 20 then
        shell.run("reboot")
    end
end

-- main:onKey(restart)

flex:onScroll(function (self, event, direction, x, y)
    local x,y = taskFrame:getOffset()
    scrollBar:setIndex(y)
end)

local function showPopup(message)
    -- Create a frame for the popup
    local popupFrame = main:addFrame("popupFrame")
        :setBackground(colors.lightGray)
        :setSize(30, 5)  -- Width and height of the popup
        :setPosition("parent.w / 2 - 15", "parent.h / 2 - 2")  -- Center the popup
        :setZIndex(100)  -- Ensure it's on top of everything

    -- Add a label to show the message
    popupFrame:addLabel()
        :setText(message)
        :setForeground(colors.black)
        :setPosition(1, 1)

    -- Add a close button
    local closeButton = popupFrame:addButton()
        :setText("Close")
        :setPosition(10, 3)  -- Position the close button
        :setSize(10, 1)
        :onClick(function()
            main:removeChild("popupFrame")  -- Remove the popup frame on click
        end)

    -- Optionally, you can set focus on the close button
    closeButton:setFocus(true)
end

-- Example usage of the popup function
-- showPopup("This is a popup message!")

-- Start the UI auto-update loop
basalt.autoUpdate()