local modem = peripheral.find("modem", rednet.open)

if not modem then
    error("Please attach a modem first.")
end

while true do
    local senderID, message, protocol = rednet.receive("GistIDChannel")
    if protocol == "GistIDChannel" then
        local file = fs.open("todolist/gist_id.txt", "w")
        file.write(message)
        file.close()
        print("Gist ID received and saved")
        break
    end
end

while true do
    local senderID, message, protocol = rednet.receive("TokenChannel")
    if protocol == "TokenChannel" then
        if message == "Failed to get Github Token" then print(message) break end
        local file = fs.open(".env", "w+")
        file.write(message)
        file.close()
        print("Github Token received and saved")
        break
    end
end
