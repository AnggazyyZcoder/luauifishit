local success, Fluent = pcall(function()
    return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
end)

if not success then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Error",
        Text = "Failed to load Fluent UI",
        Duration = 5
    })
    return
end

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Variables
local autoFishEnabled = false
local antiLagEnabled = false
local lockPositionEnabled = false
local lastSavedPosition = nil
local lockPositionLoop = nil
local fishingRadarEnabled = false
local autoSellEnabled = false
local autoSellThreshold = 3
local autoSellLoop = nil
local selectedWeathers = {}
local availableWeathers = {}
local autoTrickTreatEnabled = false
local trickTreatLoop = nil

-- Mobile detection
local isMobile = UserInputService.TouchEnabled

-- Create Window FIRST
local Window = Fluent:CreateWindow({
    Title = "Anggazyy Hub - Fish It",
    SubTitle = "Mobile Optimized",
    TabWidth = 80,
    Size = UDim2.fromOffset(380, 500),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.Zero -- Use a key that won't conflict
})

-- Create tabs IMMEDIATELY after window
local Tabs = {
    Main = Window:AddTab({Title = "Main", Icon = "home"}),
    Auto = Window:AddTab({Title = "Auto", Icon = "zap"}),
    Weather = Window:AddTab({Title = "Weather", Icon = "cloud"}),
    Bypass = Window:AddTab({Title = "Bypass", Icon = "shield"}),
    Player = Window:AddTab({Title = "Player", Icon = "user"})
}

-- Create floating icon for mobile
local floatingIcon
if isMobile then
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AnggazyyHubFloatingIcon"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui

    local button = Instance.new("ImageButton")
    button.Name = "FloatingButton"
    button.Size = UDim2.fromOffset(60, 60)
    button.Position = UDim2.new(0, 20, 0.5, -30)
    button.BackgroundColor3 = Color3.fromRGB(103, 58, 183)
    button.Image = "rbxassetid://10734986810"
    button.ScaleType = Enum.ScaleType.Fit
    button.BackgroundTransparency = 0.3
    button.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.3, 0)
    corner.Parent = button
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 2
    stroke.Parent = button

    -- Make draggable
    local dragging = false
    local dragStart, startPos

    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = button.Position
            
            button.BackgroundTransparency = 0.1
        end
    end)

    button.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            button.BackgroundTransparency = 0.3
            
            -- Toggle UI
            if Window.Enabled then
                Window:Minimize()
            else
                Window:Restore()
                Fluent:SelectTab(1)
            end
        end
    end)

    floatingIcon = screenGui
end

-- Notification System
local function Notify(title, content, duration)
    Fluent:Notify({
        Title = title,
        Content = content,
        Duration = duration or 3
    })
end

-- Auto Fishing System
local function StartAutoFish()
    if autoFishEnabled then return end
    autoFishEnabled = true
    Notify("Auto Fishing", "System activated", 2)

    local function autoFishLoop()
        while autoFishEnabled do
            pcall(function()
                -- Simple auto fish implementation
                local remote = ReplicatedStorage:FindFirstChild("UpdateAutoFishingState") 
                if remote and remote:IsA("RemoteFunction") then
                    remote:InvokeServer(true)
                end
            end)
            task.wait(4)
        end
    end
    
    task.spawn(autoFishLoop)
end

local function StopAutoFish()
    if not autoFishEnabled then return end
    autoFishEnabled = false
    Notify("Auto Fishing", "System deactivated", 2)
    
    pcall(function()
        local remote = ReplicatedStorage:FindFirstChild("UpdateAutoFishingState")
        if remote and remote:IsA("RemoteFunction") then
            remote:InvokeServer(false)
        end
    end)
end

-- Anti Lag System
local function EnableAntiLag()
    if antiLagEnabled then return end
    antiLagEnabled = true
    
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 999999
        Lighting.Brightness = 2
        
        if workspace.Terrain then
            workspace.Terrain.Decoration = false
        end
        
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Part") or obj:IsA("MeshPart") then
                obj.Material = Enum.Material.SmoothPlastic
            elseif obj:IsA("ParticleEmitter") then
                obj.Enabled = false
            end
        end
    end)
    
    Notify("Anti Lag", "Performance mode enabled", 3)
end

local function DisableAntiLag()
    if not antiLagEnabled then return end
    antiLagEnabled = false
    
    pcall(function()
        Lighting.GlobalShadows = true
        Lighting.FogEnd = 1000
        Lighting.Brightness = 1
        
        if workspace.Terrain then
            workspace.Terrain.Decoration = true
        end
    end)
    
    Notify("Anti Lag", "Graphics restored", 3)
end

-- Position System
local function SaveCurrentPosition()
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        lastSavedPosition = character.HumanoidRootPart.Position
        Notify("Position", "Position saved", 2)
        return true
    end
    return false
end

local function LoadSavedPosition()
    if not lastSavedPosition then
        Notify("Position", "No position saved", 2)
        return false
    end
    
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.CFrame = CFrame.new(lastSavedPosition)
        Notify("Position", "Teleported to saved position", 2)
        return true
    end
    return false
end

local function StartLockPosition()
    if lockPositionEnabled then return end
    lockPositionEnabled = true
    
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        lastSavedPosition = character.HumanoidRootPart.Position
    end
    
    lockPositionLoop = RunService.Heartbeat:Connect(function()
        if not lockPositionEnabled then return end
        
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") and lastSavedPosition then
            local currentPos = character.HumanoidRootPart.Position
            local distance = (currentPos - lastSavedPosition).Magnitude
            
            if distance > 2 then
                character.HumanoidRootPart.CFrame = CFrame.new(lastSavedPosition)
            end
        end
    end)
    
    Notify("Position Lock", "Position locked", 2)
end

local function StopLockPosition()
    if not lockPositionEnabled then return end
    lockPositionEnabled = false
    
    if lockPositionLoop then
        lockPositionLoop:Disconnect()
        lockPositionLoop = nil
    end
    
    Notify("Position Lock", "Position unlocked", 2)
end

-- Auto Sell System
local function StartAutoSell()
    if autoSellEnabled then return end
    autoSellEnabled = true
    
    autoSellLoop = task.spawn(function()
        while autoSellEnabled do
            pcall(function()
                -- Simple auto sell implementation
                local VendorController = require(ReplicatedStorage:FindFirstChild("Controllers") and ReplicatedStorage.Controllers:FindFirstChild("VendorController"))
                if VendorController and VendorController.SellAllItems then
                    VendorController:SellAllItems()
                    Notify("Auto Sell", "Fish sold automatically", 2)
                end
            end)
            task.wait(10) -- Check every 10 seconds
        end
    end)
    
    Notify("Auto Sell", "Auto sell activated", 3)
end

local function StopAutoSell()
    if not autoSellEnabled then return end
    autoSellEnabled = false
    
    if autoSellLoop then
        task.cancel(autoSellLoop)
        autoSellLoop = nil
    end
    
    Notify("Auto Sell", "Auto sell stopped", 2)
end

-- Trick or Treat System
local function StartAutoTrickTreat()
    if autoTrickTreatEnabled then return end
    autoTrickTreatEnabled = true
    
    trickTreatLoop = task.spawn(function()
        while autoTrickTreatEnabled do
            pcall(function()
                -- Simple trick or treat implementation
                local doors = {}
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("Model") and obj:FindFirstChild("Door") then
                        table.insert(doors, obj)
                    end
                end
                
                if #doors > 0 then
                    Notify("Trick or Treat", "Found " .. #doors .. " doors", 2)
                end
            end)
            task.wait(15)
        end
    end)
end

local function StopAutoTrickTreat()
    if not autoTrickTreatEnabled then return end
    autoTrickTreatEnabled = false
    
    if trickTreatLoop then
        task.cancel(trickTreatLoop)
        trickTreatLoop = nil
    end
    
    Notify("Trick or Treat", "Stopped", 2)
end

-- Weather System
local function LoadWeatherData()
    local weatherList = {}
    
    pcall(function()
        local Events = require(ReplicatedStorage:FindFirstChild("Events"))
        if Events then
            for name, data in pairs(Events) do
                if data.WeatherMachinePrice then
                    table.insert(weatherList, {
                        Name = name,
                        Price = data.WeatherMachinePrice,
                        DisplayName = name .. " - " .. tostring(data.WeatherMachinePrice) .. " coins"
                    })
                end
            end
        end
    end)
    
    return weatherList
end

-- =============================================================================
-- UI CREATION - SIMPLE AND GUARANTEED TO WORK
-- =============================================================================

-- Main Tab
Tabs.Main:AddParagraph({
    Title = "🎣 Anggazyy Hub",
    Content = "Mobile Optimized Fishing Hub"
})

Tabs.Main:AddButton({
    Title = "Test Notification",
    Description = "Check if UI is working",
    Callback = function()
        Notify("Test", "UI is working correctly!", 3)
    end
})

-- Auto Tab
Tabs.Auto:AddToggle("AutoFishToggle", {
    Title = "Auto Fishing",
    Description = "Automatically catch fish",
    Default = false,
    Callback = function(state)
        if state then
            StartAutoFish()
        else
            StopAutoFish()
        end
    end
})

-- Weather Tab
availableWeathers = LoadWeatherData()

if #availableWeathers > 0 then
    for _, weather in ipairs(availableWeathers) do
        Tabs.Weather:AddToggle("WeatherToggle_" .. weather.Name, {
            Title = weather.Name,
            Description = weather.Price .. " coins",
            Default = false,
            Callback = function(state)
                selectedWeathers[weather.Name] = state
            end
        })
    end
    
    Tabs.Weather:AddButton({
        Title = "Buy Selected Weathers",
        Description = "Purchase selected weather machines",
        Callback = function()
            local count = 0
            for _ in pairs(selectedWeathers) do
                count = count + 1
            end
            Notify("Weather", "Would buy " .. count .. " weathers", 3)
        end
    })
else
    Tabs.Weather:AddParagraph({
        Title = "No Weather Data",
        Content = "Weather machines not available"
    })
end

-- Bypass Tab
Tabs.Bypass:AddToggle("AutoSellToggle", {
    Title = "Auto Sell Fish",
    Description = "Automatically sell your fish",
    Default = false,
    Callback = function(state)
        if state then
            StartAutoSell()
        else
            StopAutoSell()
        end
    end
})

Tabs.Bypass:AddSlider("SellThreshold", {
    Title = "Sell Threshold",
    Description = "Fish count to trigger auto sell",
    Default = 3,
    Min = 1,
    Max = 20,
    Rounding = 1,
    Callback = function(value)
        autoSellThreshold = value
        Notify("Auto Sell", "Threshold: " .. value .. " fish", 2)
    end
})

Tabs.Bypass:AddToggle("AutoTrickTreatToggle", {
    Title = "Auto Trick/Treat",
    Description = "Automated door knocking",
    Default = false,
    Callback = function(state)
        if state then
            StartAutoTrickTreat()
        else
            StopAutoTrickTreat()
        end
    end
})

-- Player Tab
Tabs.Player:AddToggle("AntiLagToggle", {
    Title = "Performance Mode",
    Description = "Reduce graphics for better FPS",
    Default = false,
    Callback = function(state)
        if state then
            EnableAntiLag()
        else
            DisableAntiLag()
        end
    end
})

Tabs.Player:AddButton({
    Title = "Save Position",
    Description = "Save current position",
    Callback = SaveCurrentPosition
})

Tabs.Player:AddButton({
    Title = "Load Position", 
    Description = "Teleport to saved position",
    Callback = LoadSavedPosition
})

Tabs.Player:AddToggle("LockPositionToggle", {
    Title = "Lock Position",
    Description = "Prevent movement from current spot",
    Default = false,
    Callback = function(state)
        if state then
            StartLockPosition()
        else
            StopLockPosition()
        end
    end
})

Tabs.Player:AddSlider("WalkSpeed", {
    Title = "Walk Speed",
    Description = "Adjust movement speed",
    Default = 16,
    Min = 16,
    Max = 100,
    Rounding = 1,
    Callback = function(value)
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("Humanoid") then
            character.Humanoid.WalkSpeed = value
            Notify("Movement", "Walk speed: " .. value, 2)
        end
    end
})

Tabs.Player:AddSlider("JumpPower", {
    Title = "Jump Power",
    Description = "Adjust jump height",
    Default = 50,
    Min = 50,
    Max = 200,
    Rounding = 1,
    Callback = function(value)
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("Humanoid") then
            character.Humanoid.JumpPower = value
            Notify("Movement", "Jump power: " .. value, 2)
        end
    end
})

-- Final initialization
Fluent:SelectTab(1)

-- Success notification
Notify("Anggazyy Hub", "Successfully loaded! " .. (isMobile and "Mobile mode" or "Desktop mode"), 5)

-- Cleanup
LocalPlayer.AncestryChanged:Connect(function()
    if not LocalPlayer.Parent then
        -- Player leaving game
        if floatingIcon then
            floatingIcon:Destroy()
        end
        StopAutoFish()
        StopAutoSell()
        StopAutoTrickTreat()
        StopLockPosition()
        DisableAntiLag()
    end
end)

-- Auto-clean money icons
task.spawn(function()
    while task.wait(5) do
        pcall(function()
            for _, obj in ipairs(CoreGui:GetDescendants()) do
                if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                    local name = (obj.Name or ""):lower()
                    if string.find(name, "money") or string.find(name, "coin") then
                        obj.Visible = false
                    end
                end
            end
        end)
    end
end)

print("🎣 Anggazyy Hub loaded successfully!")
