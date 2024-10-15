peripheral.find("modem", rednet.open)
local modem = peripheral.find("modem")

if not modem then
    error("Please attach a modem first.")
end

local gistUtils = require("/todolist/gistUtils")
local gistID = getGistID()

if gistID then
    rednet.broadcast(gistID, "GistIDChannel")
    print("Sent GistID")
end

if ENV["GITHUB_TOKEN"] ~= nil or ENV["GITHUB_TOKEN"] ~= "enter_token_here" then -- TODO: Validate token, encrypt message
    rednet.broadcast("GITHUB_TOKEN=" .. ENV["GITHUB_TOKEN"], "TokenChannel")
    print("Sent Github Token")
else
    local msg = "Failed to get Github Token, check .env file"
    rednet.broadcast(msg, "TokenChannel")
    print(msg)
end
