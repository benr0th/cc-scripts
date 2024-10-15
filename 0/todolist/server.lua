peripheral.find("modem", rednet.open)
local gistUtils = require("/todolist/gistUtils")
local gistID = getGistID()

if gistID then
    rednet.broadcast(gistID, "GistIDChannel")
end

if ENV["GITHUB_TOKEN"] ~= nil or ENV["GITHUB_TOKEN"] ~= "enter_token_here" then -- TODO: Validate token
    rednet.broadcast("GITHUB_TOKEN=" .. ENV["GITHUB_TOKEN"], "TokenChannel")
else
    rednet.broadcast("Failed to get Github Token", "TokenChannel")
end
