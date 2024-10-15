-- File path for the tasks file
local file_path = "tasks.txt"

function readTasks()
    -- Open the file in read mode
    local file = io.open(file_path, "r")
    
    local gistID = getGistID()
    if gistID then
        downloadTasksFromGistAsync(gistID)
    else
        print("No gist ID found, creating gist")
        createGistAsync(file)
        gistID = getGistID()
    end

    -- If the file doesn't exist, return an empty tasks table
    if not file then
        print("No tasks file found, fetching.")
        downloadTasksFromGistAsync(gistID)
        -- Re-open the file after creating it
        file = io.open(file_path, "r")
    end
    
    local tasks
    
    local data = file:read("*a")

    file:close()

    if data and data ~= "" then
        tasks = textutils.unserialise(data)
    else
        tasks = {}
    end
    
    if not tasks then
        tasks = {}
    end

    return tasks
end

function writeTasks(task_table)
    local file = io.open(file_path, "w")
    
    if not file then
        print("Error opening file for writing.")
        return
    end
    
    file:write(textutils.serialise(task_table))
    
    file:close()

    syncTasks()
end