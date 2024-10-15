local dotenv = require("../dotenv")

local success, err = dotenv:load()

if success then
    print("Loaded dotenv successfully")
else
    print(err)
end

if GITHUB_TOKEN == "enter_token_here" then
    error("Please add Github Token with gist permission to the .env file")
end

local gistIDFile = "todolist/gist_id.txt" -- Store the ID of the Gist once created
local tasksFile = "tasks.txt"

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

function createGistAsync(fileContent)
    local url = "https://api.github.com/gists"
    local body = textutils.serializeJSON({
        description = "Tasks file from ComputerCraft",
        public = false,
        files = {
            ["tasks.txt"] = { content = fileContent or "dummy" }
        }
    })
    local headers = {
        ["Authorization"] = "token " .. GITHUB_TOKEN,
        ["Content-Type"] = "application/json"
    }

    http.request(url, body, headers)
end

function updateGistAsync(gistID, fileContent)
    local url = "https://api.github.com/gists/" .. gistID
    local body = textutils.serializeJSON({
        files = {
            ["tasks.txt"] = { content = fileContent or "dummy" }
        }
    })
    local headers = {
        ["Authorization"] = "token " .. GITHUB_TOKEN,
        ["Content-Type"] = "application/json"
    }

    http.request(url, body, headers)
end

function downloadTasksFromGistAsync(gistID)
    local url = "https://api.github.com/gists/" .. gistID
    local headers = {
        ["Authorization"] = "token " .. GITHUB_TOKEN
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
                local file = fs.open(tasksFile, "w")
                file.write(gistContent)
                file.close()
                print("Tasks downloaded successfully!")
            elseif data and data.id then
                saveGistID(data.id)
                print("Gist created/updated successfully!")
            end
        elseif event == "http_failure" then
            print("HTTP request failed: " .. url)
        end
    end
end

function syncTasks()
    -- Asynchronously download tasks from Gist (if Gist ID exists)
    local gistID = getGistID()
    if gistID then
        downloadTasksFromGistAsync(gistID)
    end

    -- Upload (or update) the tasks file asynchronously
    local fileContent = "dummy"
    if fs.exists(tasksFile) then
        local file = fs.open(tasksFile, "r")
        fileContent = file.readAll()
        file.close()
    end

    if gistID then
        updateGistAsync(gistID, fileContent)
    else
        createGistAsync(fileContent)
    end
end

-- Main loop to handle HTTP responses
parallel.waitForAny(syncTasks, handleHttpEvent)