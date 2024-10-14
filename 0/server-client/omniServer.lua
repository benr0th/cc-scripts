local manager = peripheral.find("inventoryManager")
local meBridge = peripheral.find("meBridge")
peripheral.find("modem", rednet.open)

-- JSON handling
local function loadTools()
   if fs.exists("tools.json") then
      local file = fs.open("tools.json", "r")
      local data = textutils.unserializeJSON(file.readAll())
      file.close()
      return data
   end
   return {}
end

local function saveTools(tools)
   local file = fs.open("tools.json", "w")
   file.write(textutils.serializeJSON(tools))
   file.close()
end

local tools = loadTools()

-- Function to check tool availability
local function isToolAvailable(toolName)
   local item, err = meBridge.getItem({ name = toolName.name })
   if err then return false end
   if item.amount ~= nil then
      return item.amount > 0
   end
   return false
end

-- Function to get tool status list
local function getToolStatus()
   local statusList = {}
   for i, tool in ipairs(tools) do
      statusList[i] = {
         name = tool.name,
         available = isToolAvailable(tool)
      }
   end
   return statusList
end

-- Function to get player inventory
local function getPlayerInventory()
   local inventory = manager.getItems()
   return inventory
end

-- Function to swap tools
local function swapTool(newTool)
   for _, tool in ipairs(tools) do
      manager.removeItemFromPlayer("left", { name = tool.name })
      meBridge.importItem({ name = tool.name }, "down")
      
   end
   meBridge.exportItem({ name = newTool.name }, "down")
   manager.addItemToPlayer("left", { name = newTool.name })
   return "Swapped to " .. newTool.name
end

local function main()
   print("Omnitool server started")
   -- Main loop
   while true do
      local senderId, message = rednet.receive()
      if message.command == "get_status" then
         rednet.send(senderId, {
            type = "status",
            data = getToolStatus()
         })
      elseif message.command == "swap_tool" then
         local toolIndex = message.toolIndex
         if toolIndex >= 1 and toolIndex <= #tools then
            local selectedTool = tools[toolIndex]
            if isToolAvailable(selectedTool) then
               local result = swapTool(selectedTool)
               rednet.send(senderId, {
                  type = "swap_result",
                  success = true,
                  message = result
               })
            else
               rednet.send(senderId, {
                  type = "swap_result",
                  success = false,
                  message = "Tool not available!"
               })
            end
         end
      elseif message.command == "get_inventory" then
         rednet.send(senderId, {
            type = "inventory",
            data = getPlayerInventory()
         })
      elseif message.command == "add_tool" then
         table.insert(tools, message.tool)
         saveTools(tools)
         rednet.send(senderId, {
            type = "tool_added",
            success = true
         })
      elseif message.command == "remove_tool" then
         table.remove(tools, message.index)
         saveTools(tools)
         rednet.send(senderId, {
            type = "tool_removed",
            success = true
         })
      end
   end
end

main()