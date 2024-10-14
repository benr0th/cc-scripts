peripheral.find("modem", rednet.open)

local hostId = 0 -- Set this to your host computer ID
local currentMenu = "main"
local menuHistory = {}

local function pushMenu(menu)
    table.insert(menuHistory, currentMenu)
    currentMenu = menu
end

local function popMenu()
    if #menuHistory > 0 then
        currentMenu = table.remove(menuHistory)
        return true
    end
    return false
end

local function handleClick(numOptions, hasBackOption)
    while true do
        local event, button, x, y = os.pullEvent("mouse_click")
        if button == 1 then
            if y >= 2 and y < 2 + numOptions then
                return y - 1
            elseif hasBackOption and y == 2 + numOptions then
                return "back"
            end
        end
    end
end

local function refreshList()
    rednet.send(hostId, { command = "get_status" })
    local _, response = rednet.receive(1)
    if response and response.type == "status" then
        return response.data
    end
    return nil
end

local function displayTools(toolStatus)
    term.clear()
    term.setCursorPos(1, 1)
    print("Available Tools:")
    for i, tool in ipairs(toolStatus) do
        if tool.available then
            term.setTextColor(colors.white)
        else
            term.setTextColor(colors.red)
        end
        print(i .. ". " .. tool.name)
    end
    term.setTextColor(colors.yellow)
    if #menuHistory == 0 then
        print((#toolStatus + 1) .. ". Add/Remove Tool")
        print((#toolStatus + 2) .. ". Quit")
    end
    if #menuHistory > 0 then
        term.setTextColor(colors.lightBlue)
        print((#toolStatus + 3) .. ". Back")
    end
    term.setTextColor(colors.white)
end

local function displayAddRemoveMenu()
    term.clear()
    term.setCursorPos(1, 1)
    print("Choose option:")
    print("1. Add Tool")
    print("2. Remove Tool")
    term.setTextColor(colors.lightBlue)
    print("3. Back")
    term.setTextColor(colors.white)
end

local function displayInventory(inventory)
    term.clear()
    term.setCursorPos(1, 1)
    print("Select item to add:")
    for i, item in ipairs(inventory) do
        print(i .. ". " .. item.name)
    end
    term.setTextColor(colors.lightBlue)
    print((#inventory + 1) .. ". Back")
    term.setTextColor(colors.white)
end

local function handleMainMenu(toolStatus)
    local maxOptions = #toolStatus + 3 -- +3 for header, "Add/Remove Tool" and "Quit"
    local choice = handleClick(maxOptions, #menuHistory > 0)

    if type(choice) == "number" then
        if choice <= #toolStatus then
            rednet.send(hostId, {
                command = "swap_tool",
                toolIndex = choice
            })
            local _, result = rednet.receive(1)
            if result and result.type == "swap_result" then
                print("Swapped")
                os.sleep(0.5)
                return true
            end
        elseif choice == #toolStatus + 1 then
            pushMenu("addremove")
        elseif choice == #toolStatus + 2 then
            return false -- Quit
        end
    elseif choice == "back" then
        popMenu()
    end
    return true
end

local function handleAddRemoveMenu()
    local choice = handleClick(2, true)
    if choice == 1 then
        pushMenu("add")
    elseif choice == 2 then
        pushMenu("remove")
    elseif choice == "back" then
        popMenu()
    end
    return true
end

local function displayInventoryGrid(inventory)
    term.clear()
    term.setCursorPos(1, 1)
    print("Select item to add:")
    print("+-+-+-+-+-+-+-+-+-+") -- Column numbers

    local grid = {}
    for i = 0, 35 do -- Start at 0
        grid[i] = "."
    end

    -- Fill grid with items
    for _, item in pairs(inventory) do
        if item.slot >= 0 and item.slot <= 35 then -- Check from 0 to 35
            grid[item.slot] = "#"
        end
    end

    -- Display grid
    local rowOrder = { 2, 3, 4, 1 }
    for displayRow = 1, 4 do
        local actualRow = rowOrder[displayRow]
        local rowStr = tostring(displayRow)
        for col = 1, 9 do
            local index = ((actualRow - 1) * 9 + col) - 1 -- Subtract 1 for 0-based index
            rowStr = rowStr .. " " .. grid[index]
        end
        print(rowStr)
    end

    term.setTextColor(colors.lightBlue)
    print("\nBack")
    term.setTextColor(colors.white)
end

local function getSlotFromClick(x, y)
    if y >= 3 and y <= 6 and x >= 2 and x <= 20 then
        local displayRow = y - 2
        local rowOrder = { 2, 3, 4, 1 } -- Convert display row to actual row
        local actualRow = rowOrder[displayRow]
        local col = math.floor((x - 2) / 2) + 1
        if col <= 9 then
            return ((actualRow - 1) * 9 + col) - 1
        end
    end
    return nil
end

local function handleInventoryMenu(inventory)
    while true do
        displayInventoryGrid(inventory)
        local event, button, x, y = os.pullEvent("mouse_click")
        if button == 1 then
            if y == 8 then -- Back button
                return "back"
            end

            local slot = getSlotFromClick(x, y)
            if slot ~= nil then
                for _, item in pairs(inventory) do
                    if item.slot == slot then
                        return item
                    end
                end
            end
        end
    end
end

local function handleAddMenu()
    rednet.send(hostId, { command = "get_inventory" })
    local _, response = rednet.receive(1)
    if response and response.type == "inventory" then
        local selectedItem = handleInventoryMenu(response.data)
        if selectedItem == "back" then
            popMenu()
        elseif selectedItem then
            rednet.send(hostId, {
                command = "add_tool",
                tool = selectedItem
            })
            local _, result = rednet.receive(1)
            if result and result.type == "tool_added" then
                print("Added " .. selectedItem.name)
                os.sleep(0.5) -- Add delay as discussed
                refreshList()
                popMenu()
            end
        end
    end
    return true
end

local function handleRemoveMenu(toolStatus)
    local choice = handleClick(#toolStatus, true)
    if type(choice) == "number" then
        rednet.send(hostId, {
            command = "remove_tool",
            index = choice
        })
        local _, result = rednet.receive(1)
        if result and result.type == "tool_removed" then
            popMenu()
        end
    elseif choice == "back" then
        popMenu()
    end
    return true
end

-- Main loop
while true do
    if currentMenu == "main" then
        rednet.send(hostId, { command = "get_status" })
        local _, response = rednet.receive(1)
        if response and response.type == "status" then
            displayTools(response.data)
            if not handleMainMenu(response.data) then
                break
            end
        end
    elseif currentMenu == "addremove" then
        displayAddRemoveMenu()
        if not handleAddRemoveMenu() then
            break
        end
    elseif currentMenu == "add" then
        rednet.send(hostId, { command = "get_inventory" })
        local _, response = rednet.receive(1)
        if response and response.type == "inventory" then
            -- displayInventory(response.data)
            if not handleAddMenu() then
                break
            end
        end
    elseif currentMenu == "remove" then
        rednet.send(hostId, { command = "get_status" })
        local _, response = rednet.receive(1)
        if response and response.type == "status" then
            displayTools(response.data)
            if not handleRemoveMenu(response.data) then
                break
            end
        end
    end
end
