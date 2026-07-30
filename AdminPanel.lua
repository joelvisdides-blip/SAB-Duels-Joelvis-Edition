--[[
    AdminPanel.lua
    ONE FILE SETUP:
    Place this as a Script inside ServerScriptService. That's it.

    It runs the server logic AND automatically creates/injects the
    client GUI LocalScript into StarterGui at runtime, so you don't
    need to place a second file anywhere.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

----------------------------------------------------------------
-- CONFIG: put your Roblox UserIds here
----------------------------------------------------------------
local ADMIN_IDS = {
    [123456789] = true, -- replace with your UserId
    -- [987654321] = true, -- add more admins here
}

local DEFAULT_SPEED = 16
local DEFAULT_JUMPPOWER = 50
local BOOST_SPEED = 50
local BOOST_JUMPPOWER = 100

----------------------------------------------------------------
-- Remote setup
----------------------------------------------------------------
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "AdminRemotes"
remotesFolder.Parent = ReplicatedStorage

local function makeRemote(name)
    local re = Instance.new("RemoteEvent")
    re.Name = name
    re.Parent = remotesFolder
    return re
end

local ToggleSpeed        = makeRemote("ToggleSpeed")
local ToggleInfiniteJump = makeRemote("ToggleInfiniteJump")
local ToggleNoclip       = makeRemote("ToggleNoclip")
local TeleportToPlayer   = makeRemote("TeleportToPlayer")
local KickPlayer         = makeRemote("KickPlayer")
local SpawnItem          = makeRemote("SpawnItem")
local RequestPlayerList  = makeRemote("RequestPlayerList")
local AdminStatus        = makeRemote("AdminStatus")

----------------------------------------------------------------
-- State
----------------------------------------------------------------
local noclipConnections = {}
local infiniteJumpEnabled = {}

local function isAdmin(player)
    return ADMIN_IDS[player.UserId] == true
end

----------------------------------------------------------------
-- Speed toggle
----------------------------------------------------------------
ToggleSpeed.OnServerEvent:Connect(function(player, enabled)
    if not isAdmin(player) then return end
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.WalkSpeed = enabled and BOOST_SPEED or DEFAULT_SPEED
end)

----------------------------------------------------------------
-- Infinite jump toggle
----------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        local humanoid = char:WaitForChild("Humanoid")

        humanoid.StateChanged:Connect(function(_, newState)
            if infiniteJumpEnabled[player.UserId] and newState == Enum.HumanoidStateType.Freefall then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)

        if infiniteJumpEnabled[player.UserId] then
            humanoid.JumpPower = BOOST_JUMPPOWER
        end
    end)

    -- Tell the client whether they're an admin
    AdminStatus:FireClient(player, isAdmin(player))
end)

ToggleInfiniteJump.OnServerEvent:Connect(function(player, enabled)
    if not isAdmin(player) then return end
    infiniteJumpEnabled[player.UserId] = enabled

    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.JumpPower = enabled and BOOST_JUMPPOWER or DEFAULT_JUMPPOWER
        end
    end
end)

----------------------------------------------------------------
-- Noclip toggle
----------------------------------------------------------------
local function setNoclip(player, enabled)
    local char = player.Character
    if not char then return end

    if noclipConnections[player.UserId] then
        noclipConnections[player.UserId]:Disconnect()
        noclipConnections[player.UserId] = nil
    end

    if enabled then
        noclipConnections[player.UserId] = RunService.Stepped:Connect(function()
            if not char or not char.Parent then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    else
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

ToggleNoclip.OnServerEvent:Connect(function(player, enabled)
    if not isAdmin(player) then return end
    setNoclip(player, enabled)
end)

----------------------------------------------------------------
-- Teleport to player
----------------------------------------------------------------
TeleportToPlayer.OnServerEvent:Connect(function(player, targetName)
    if not isAdmin(player) then return end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local target = Players:FindFirstChild(targetName)
    if not target or not target.Character then return end

    local targetHrp = target.Character:FindFirstChild("HumanoidRootPart")
    if not targetHrp then return end

    hrp.CFrame = targetHrp.CFrame + Vector3.new(0, 3, 0)
end)

----------------------------------------------------------------
-- Kick player
----------------------------------------------------------------
KickPlayer.OnServerEvent:Connect(function(player, targetName, reason)
    if not isAdmin(player) then return end

    local target = Players:FindFirstChild(targetName)
    if target then
        target:Kick(reason ~= "" and reason or "Kicked by admin")
    end
end)

----------------------------------------------------------------
-- Spawn item (point this at a folder of tools in ReplicatedStorage)
----------------------------------------------------------------
SpawnItem.OnServerEvent:Connect(function(player, itemName)
    if not isAdmin(player) then return end

    local itemsFolder = ReplicatedStorage:FindFirstChild("AdminItems")
    if not itemsFolder then return end

    local item = itemsFolder:FindFirstChild(itemName)
    if not item then return end

    local clone = item:Clone()
    clone.Parent = player.Backpack
end)

----------------------------------------------------------------
-- Player list
----------------------------------------------------------------
RequestPlayerList.OnServerEvent:Connect(function(player)
    if not isAdmin(player) then return end

    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            table.insert(names, p.Name)
        end
    end

    RequestPlayerList:FireClient(player, names)
end)

----------------------------------------------------------------
-- CLIENT UI SOURCE
-- This is injected as a LocalScript into StarterGui below, so the
-- whole panel ships from this one Script.
----------------------------------------------------------------
local CLIENT_SOURCE = [[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("AdminRemotes")

local ToggleSpeed        = remotes:WaitForChild("ToggleSpeed")
local ToggleInfiniteJump = remotes:WaitForChild("ToggleInfiniteJump")
local ToggleNoclip       = remotes:WaitForChild("ToggleNoclip")
local TeleportToPlayer   = remotes:WaitForChild("TeleportToPlayer")
local KickPlayer         = remotes:WaitForChild("KickPlayer")
local AdminStatus        = remotes:WaitForChild("AdminStatus")

local function buildUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AdminPanel"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")

    local openButton = Instance.new("TextButton")
    openButton.Size = UDim2.new(0, 50, 0, 50)
    openButton.Position = UDim2.new(0, 20, 0, 20)
    openButton.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    openButton.Text = "\226\154\153"
    openButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    openButton.TextScaled = true
    openButton.Font = Enum.Font.GothamBold
    openButton.Parent = screenGui
    Instance.new("UICorner", openButton).CornerRadius = UDim.new(1, 0)

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 260, 0, 380)
    frame.Position = UDim2.new(0, 20, 0, 80)
    frame.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
    frame.Visible = false
    frame.Parent = screenGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(70, 70, 90)
    stroke.Thickness = 1
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text = "Admin Panel"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = frame

    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -20, 1, -50)
    contentFrame.Position = UDim2.new(0, 10, 0, 45)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = frame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 8)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = contentFrame

    openButton.MouseButton1Click:Connect(function()
        frame.Visible = not frame.Visible
    end)

    local function makeToggle(order, labelText, onToggle)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 36)
        btn.LayoutOrder = order
        btn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
        btn.Text = labelText .. ": OFF"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 14
        btn.Parent = contentFrame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

        local state = false
        btn.MouseButton1Click:Connect(function()
            state = not state
            btn.Text = labelText .. ": " .. (state and "ON" or "OFF")
            btn.BackgroundColor3 = state and Color3.fromRGB(50, 130, 80) or Color3.fromRGB(45, 45, 58)
            onToggle(state)
        end)
        return btn
    end

    makeToggle(1, "Speed Boost", function(state) ToggleSpeed:FireServer(state) end)
    makeToggle(2, "Infinite Jump", function(state) ToggleInfiniteJump:FireServer(state) end)
    makeToggle(3, "Noclip", function(state) ToggleNoclip:FireServer(state) end)

    local targetBox = Instance.new("TextBox")
    targetBox.Size = UDim2.new(1, 0, 0, 32)
    targetBox.LayoutOrder = 4
    targetBox.PlaceholderText = "Target username..."
    targetBox.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
    targetBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    targetBox.Font = Enum.Font.Gotham
    targetBox.TextSize = 14
    targetBox.Parent = contentFrame
    Instance.new("UICorner", targetBox).CornerRadius = UDim.new(0, 8)

    local teleportBtn = Instance.new("TextButton")
    teleportBtn.Size = UDim2.new(1, 0, 0, 32)
    teleportBtn.LayoutOrder = 5
    teleportBtn.Text = "Teleport To Player"
    teleportBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
    teleportBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    teleportBtn.Font = Enum.Font.Gotham
    teleportBtn.TextSize = 14
    teleportBtn.Parent = contentFrame
    Instance.new("UICorner", teleportBtn).CornerRadius = UDim.new(0, 8)

    teleportBtn.MouseButton1Click:Connect(function()
        if targetBox.Text ~= "" then
            TeleportToPlayer:FireServer(targetBox.Text)
        end
    end)

    local kickBtn = Instance.new("TextButton")
    kickBtn.Size = UDim2.new(1, 0, 0, 32)
    kickBtn.LayoutOrder = 6
    kickBtn.Text = "Kick Player"
    kickBtn.BackgroundColor3 = Color3.fromRGB(120, 45, 45)
    kickBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    kickBtn.Font = Enum.Font.Gotham
    kickBtn.TextSize = 14
    kickBtn.Parent = contentFrame
    Instance.new("UICorner", kickBtn).CornerRadius = UDim.new(0, 8)

    kickBtn.MouseButton1Click:Connect(function()
        if targetBox.Text ~= "" then
            KickPlayer:FireServer(targetBox.Text, "Kicked by admin")
        end
    end)
end

AdminStatus.OnClientEvent:Connect(function(adminConfirmed)
    if adminConfirmed then
        buildUI()
    end
end)
]]

----------------------------------------------------------------
-- Inject the client script into StarterGui so nothing else
-- needs to be placed manually
----------------------------------------------------------------
local existing = StarterGui:FindFirstChild("AdminPanelClient")
if existing then
    existing:Destroy()
end

local clientScript = Instance.new("LocalScript")
clientScript.Name = "AdminPanelClient"
clientScript.Source = CLIENT_SOURCE
clientScript.Parent = StarterGui

print("[AdminPanel] Loaded as a single script. Client UI injected into StarterGui.")
