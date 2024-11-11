local dotenv = require("../dotenv")
-- peripheral.find("modem", rednet.open)
-- local basalt = require("basalt")
ENV = ENV or {}

local success, err = dotenv:load()

if success then
    print("Loaded dotenv successfully")
else
    print(err)
end

if ENV["GITHUB_TOKEN"] == "enter_token_here" or ENV["GITHUB_TOKEN"] == nil or ENV["GITHUB_TOKEN"] == "" then -- TODO: validate token
    error("Please add Github Token with gist permission to the .env file")
end

local gistIDFile = "todolist/gist_id.txt" -- Store the ID of the Gist once created
local tasksFile = "todolist/tasks.txt"

function getGistID()
    if fs.exists(gistIDFile) then
        local file = fs.open(gistIDFile, "r")
        local gistID = file.readAll()
        file.close()
        return gistID
    end
    return nil
end

local function saveGistID(gistID)
    local file = fs.open(gistIDFile, "w")
    file.write(gistID)
    file.close()
end

-- Function to create a new Gist
function createGist(fileContent)
    local url = "https://api.github.com/gists"
    local body = textutils.serializeJSON({
        description = "Tasks file from ComputerCraft",
        public = false,
        files = {
            ["tasks.txt"] = { content = fileContent or "{}" } -- Ensure content is never nil
        }
    })
    local headers = {
        ["Authorization"] = "token " .. ENV["GITHUB_TOKEN"],
        ["Content-Type"] = "application/json"
    }

    local response = http.post(url, body, headers)
    if response then
        local data = textutils.unserializeJSON(response.readAll())
        response.close()

        if data and data.id then
            saveGistID(data.id)
            print("Gist created successfully! Gist URL: " .. data.html_url)
        else
            print("Failed to create gist.")
        end
    else
        error("Failed to create gist.")
    end

end

function updateGistAsync(gistID, fileContent)
    local url = "https://api.github.com/gists/" .. gistID
    local body = textutils.serializeJSON({
        files = {
            ["tasks.txt"] = { content = fileContent or "{}" }
        }
    })
    local headers = {
        ["Authorization"] = "token " .. ENV["GITHUB_TOKEN"],
        ["Content-Type"] = "application/json",
        ["X-HTTP-Method-Override"] = "PATCH"
    }

    http.request(url, body, headers)
end

function updateGist(gistID, fileContent)
    local url = "https://api.github.com/gists/" .. gistID
    local body = textutils.serializeJSON({
        files = {
            ["tasks.txt"] = { content = fileContent or "{}" }
        }
    })
    local headers = {
        ["Authorization"] = "token " .. ENV["GITHUB_TOKEN"],
        ["X-HTTP-Method-Override"] = "PATCH"
    }

    local response = http.post(url, body, headers)
    if response then
        local data = textutils.unserializeJSON(response.readAll())
        response.close()

        if data and data.files and data.files["tasks.txt"] then
            print("Gist updated successfully!")
        else
            print("Failed to create gist.")
        end
    else
        print("Failed to create gist.")
    end
end

function downloadTasksFromGist(gistID)
    local url = "https://api.github.com/gists/" .. gistID
    local headers = {
        ["Authorization"] = "token " .. ENV["GITHUB_TOKEN"]
    }

    local response = http.get(url, headers)
    if response then
        local data = textutils.unserializeJSON(response.readAll())
        response.close()

        if data and data.files and data.files["tasks.txt"] then
            local gistContent = data.files["tasks.txt"].content
            -- local file = fs.open("todolist/tasks.txt", "w")
            -- file.write(gistContent)
            -- file.close()
            print("Downloaded tasks from Gist successfully!")
            return gistContent
        else
            print("Failed to get tasks from Gist.")
        end
    else
        print("Failed to download from Gist.")
    end
end

local function downloadTasksFromGistAsync(gistID)
    local url = "https://api.github.com/gists/" .. gistID
    local headers = {
        ["Authorization"] = "token " .. ENV["GITHUB_TOKEN"]
    }

    http.request(url, nil, headers)
end

local function handleHttpEvent()
    while true do
        local event, url, response = os.pullEvent()

        if event == "http_success" then
            local data = textutils.unserializeJSON(response.readAll())
            response.close()

            if data and data.files and data.files["tasks.txt"] then
                local gistContent = data.files["tasks.txt"].content
                -- local file = fs.open(tasksFile, "w")
                -- file.write(gistContent)
                -- file.close()
                print("Tasks downloaded successfully!")
                return gistContent
            elseif data then
                print("Gist updated successfully!")
            end
        elseif event == "http_failure" then
            print("HTTP request failed: " .. url)
        end

    end
end

function syncTasks(fileContent, shouldSync)
    -- Asynchronously download tasks from Gist (if Gist ID exists)
    local gistID = getGistID()
    -- if gistID then
    --     downloadTasksFromGist(gistID)
    -- end

    -- Upload (or update) the tasks file asynchronously
    -- local fileContent = "3"
    -- if fs.exists(tasksFile) then
    --     local file = fs.open(tasksFile, "r")
    --     fileContent = file.readAll()
    --     file.close()
    -- end

    if gistID then
        if shouldSync then
            updateGist(gistID, fileContent)
            -- basalt.debug("sent update")
            -- rednet.broadcast("updateList", "updateProtocol")
        end
    else
        createGist(fileContent)
    end
end

local function updateTaskList()
    -- basalt.debug("update?")
    while true do
        local senderID, message, protocol = rednet.receive("updateProtocol")
        if protocol == "updateProtocol" then
            makeTaskList()
        end
    end
end

-- Main loop to handle HTTP responses
parallel.waitForAny(syncTasks, handleHttpEvent)