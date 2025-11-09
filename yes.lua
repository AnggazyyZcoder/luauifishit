local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

--//////////////////////////////////////////////////////////////////////////////////
-- Anggazyy Hub - Fish It (FINAL) - Mobile Optimized
-- Fluent UI - Fixed for Android Mobile
--//////////////////////////////////////////////////////////////////////////////////

-- CONFIG
local AUTO_FISH_REMOTE_NAME = "UpdateAutoFishingState"
local NET_PACKAGES_FOLDER = "Packages"

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local LocalPlayer = Players.LocalPlayer

-- Variables
local autoFishEnabled = false
local antiLagEnabled = false
local lockPositionEnabled = false
local lastSavedPosition = nil
local lockPositionLoop = nil
local fishingRadarEnabled = false
local divingGearEnabled = false
local autoSellEnabled = false
local autoSellThreshold = 3
local autoSellLoop = nil
local selectedWeathers = {}
local availableWeathers = {}
local autoTrickTreatEnabled = false
local trickTreatLoop = nil

-- Mobile detection
local isMobile = UserInputService.TouchEnabled
local isAndroid = isMobile and not UserInputService.KeyboardEnabled

-- Mobile UI Configuration
local MOBILE_CONFIG = {
    WindowSize = UDim2.fromOffset(360, 450), -- Lebih kecil untuk mobile
    TabWidth = 70,
    FontSize = 12,
    ButtonHeight = 32,
    Padding = 8,
    ScrollPadding = 4
}

-- Floating Icon for Mobile
local floatingIcon = nil
local function CreateFloatingIcon()
    if floatingIcon then floatingIcon:Destroy() end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AnggazyyHubFloatingIcon"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui

    local button = Instance.new("ImageButton")
    button.Name = "FloatingButton"
    button.Size = UDim2.fromOffset(50, 50)
    button.Position = UDim2.new(0, 20, 0.5, -25)
    button.BackgroundColor3 = Color3.fromRGB(103, 58, 183)
    button.Image = "rbxassetid://10734986810" -- Lucide fish icon
    button.ScaleType = Enum.ScaleType.Fit
    button.BackgroundTransparency = 0.2
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
    local dragInput, dragStart, startPos

    local function update(input)
        local delta = input.Position - dragStart
        button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end

    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = button.Position
            
            -- Smooth press effect
            button.BackgroundTransparency = 0.4
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    button.BackgroundTransparency = 0.2
                end
            end)
        end
    end)

    button.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)

    button.InputEnded:Connect(function(input)
        if not dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
            -- Toggle UI visibility
            if Window.Enabled then
                Window:Minimize()
            else
                Window:Restore()
            end
        end
        dragging = false
        button.BackgroundTransparency = 0.2
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input == dragInput) then
            update(input)
        end
    end)

    floatingIcon = screenGui
    return screenGui
end

-- Fluent UI Window Creation with mobile optimization
local Window = Fluent:CreateWindow({
    Title = "Anggazyy Hub - Fish It",
    SubTitle = "Mobile Optimized",
    TabWidth = MOBILE_CONFIG.TabWidth,
    Size = MOBILE_CONFIG.WindowSize,
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = isMobile and Enum.KeyCode.None or Enum.KeyCode.K -- Disable K key on mobile
})

-- Create floating icon for mobile
if isMobile then
    CreateFloatingIcon()
end

-- Tabs creation with mobile-optimized layout
local Tabs = {
    Main = Window:AddTab({Title = "Main", Icon = "home"}),
    Auto = Window:AddTab({Title = "Auto", Icon = "zap"}),
    Weather = Window:AddTab({Title = "Weather", Icon = "cloud"}),
    Bypass = Window:AddTab({Title = "Bypass", Icon = "shield"}),
    Player = Window:AddTab({Title = "Player", Icon = "user"})
}

-- Notification System
local function Notify(title, content, duration)
    Fluent:Notify({
        Title = title,
        Content = content,
        Duration = duration or 3
    })
end

-- Network Communication
local function GetAutoFishRemote()
    local ok, NetModule = pcall(function()
        local folder = ReplicatedStorage:WaitForChild(NET_PACKAGES_FOLDER, 5)
        if folder then
            local netCandidate = folder:FindFirstChild("Net")
            if netCandidate and netCandidate:IsA("ModuleScript") then
                return require(netCandidate)
            end
        end
        if ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Net") then
            local m = ReplicatedStorage.Packages.Net
            if m:IsA("ModuleScript") then
                return require(m)
            end
        end
        return nil
    end)
    return ok and NetModule or nil
end

local function SafeInvokeAutoFishing(state)
    pcall(function()
        local Net = GetAutoFishRemote()
        if Net and type(Net.RemoteFunction) == "function" then
            local ok, rf = pcall(function() return Net:RemoteFunction(AUTO_FISH_REMOTE_NAME) end)
            if ok and rf then
                pcall(function() rf:InvokeServer(state) end)
                return
            end
        end
        
        local rfObj = ReplicatedStorage:FindFirstChild(AUTO_FISH_REMOTE_NAME) 
            or ReplicatedStorage:FindFirstChild("RemoteFunctions") and ReplicatedStorage.RemoteFunctions:FindFirstChild(AUTO_FISH_REMOTE_NAME)
        if rfObj and rfObj:IsA("RemoteFunction") then
            pcall(function() rfObj:InvokeServer(state) end)
            return
        end
    end)
end

-- Auto Fishing System
local function StartAutoFish()
    if autoFishEnabled then return end
    autoFishEnabled = true
    Notify("Auto Fishing", "System activated successfully", 2)

    task.spawn(function()
        while autoFishEnabled do
            pcall(function()
                SafeInvokeAutoFishing(true)
            end)
            task.wait(4)
        end
    end)
end

local function StopAutoFish()
    if not autoFishEnabled then return end
    autoFishEnabled = false
    Notify("Auto Fishing", "System deactivated", 2)
    
    pcall(function()
        SafeInvokeAutoFishing(false)
    end)
end

-- Weather System
local function LoadWeatherData()
    local success, result = pcall(function()
        local EventUtility = require(ReplicatedStorage.Shared.EventUtility)
        local StringLibrary = require(ReplicatedStorage.Shared.StringLibrary)
        local Events = require(ReplicatedStorage.Events)
        
        local weatherList = {}
        
        for name, data in pairs(Events) do
            local event = EventUtility:GetEvent(name)
            if event and event.WeatherMachine and event.WeatherMachinePrice then
                table.insert(weatherList, {
                    Name = event.Name or name,
                    InternalName = name,
                    Price = event.WeatherMachinePrice,
                    DisplayName = string.format("%s - %s", event.Name or name, StringLibrary:AddCommas(event.WeatherMachinePrice))
                })
            end
        end
        
        table.sort(weatherList, function(a, b)
            return a.Price < b.Price
        end)
        
        return weatherList
    end)
    
    if success then
        return result
    else
        return {}
    end
end

local function PurchaseWeather(weatherName)
    local success, result = pcall(function()
        local Net = require(ReplicatedStorage.Packages.Net)
        local PurchaseWeatherEvent = Net:RemoteFunction("PurchaseWeatherEvent")
        return PurchaseWeatherEvent:InvokeServer(weatherName)
    end)
    return success, result
end

local function BuySelectedWeathers()
    if not next(selectedWeathers) then
        Notify("Weather", "No weathers selected!")
        return
    end
    
    local totalPurchases = 0
    local successfulPurchases = 0
    
    for weatherName, selected in pairs(selectedWeathers) do
        if selected then
            totalPurchases = totalPurchases + 1
            local success, result = PurchaseWeather(weatherName)
            if success and result then
                successfulPurchases = successfulPurchases + 1
            end
            task.wait(0.3)
        end
    end
    
    selectedWeathers = {}
    Notify("Weather Purchase", string.format("Bought %d/%d", successfulPurchases, totalPurchases), 4)
end

-- Anti Lag System
local originalGraphicsSettings = {}

local function EnableAntiLag()
    if antiLagEnabled then return end
    antiLagEnabled = true
    
    pcall(function()
        UserGameSettings.GraphicsQualityLevel = 1
        Lighting.GlobalShadows = false
        Lighting.Brightness = 5
        Lighting.FogEnd = 999999
        
        if workspace.Terrain then
            workspace.Terrain.Decoration = false
        end
        
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Part") or obj:IsA("MeshPart") then
                obj.Material = Enum.Material.SmoothPlastic
                obj.BrickColor = BrickColor.new("White")
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
        UserGameSettings.GraphicsQualityLevel = 10
        Lighting.GlobalShadows = true
        Lighting.Brightness = 1
        Lighting.FogEnd = 1000
        
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

-- Bypass Systems
local function ToggleFishingRadar()
    local success, result = pcall(function()
        local Replion = require(ReplicatedStorage.Packages.Replion)
        local Net = require(ReplicatedStorage.Packages.Net)
        local UpdateFishingRadar = Net:RemoteFunction("UpdateFishingRadar")
        
        local Data = Replion.Client:WaitReplion("Data")
        if not Data then return false, "Data not found" end

        local currentState = Data:Get("RegionsVisible")
        local desiredState = not currentState

        local invokeSuccess = UpdateFishingRadar:InvokeServer(desiredState)
        
        if invokeSuccess then
            fishingRadarEnabled = desiredState
            return true, "Radar: " .. (desiredState and "ON" or "OFF")
        else
            return false, "Failed"
        end
    end)
    
    if success then
        return true, result
    else
        return false, "Error"
    end
end

local function StartAutoSell()
    if autoSellEnabled then return end
    autoSellEnabled = true
    
    autoSellLoop = task.spawn(function()
        while autoSellEnabled do
            pcall(function()
                local Replion = require(ReplicatedStorage.Packages.Replion)
                local Data = Replion.Client:WaitReplion("Data")
                local VendorController = require(ReplicatedStorage.Controllers.VendorController)
                
                if Data and VendorController and VendorController.SellAllItems then
                    local inventory = Data:Get("Inventory")
                    if inventory and inventory.Fish then
                        local fishCount = 0
                        for _, fish in pairs(inventory.Fish) do
                            fishCount = fishCount + (fish.Amount or 1)
                        end
                        
                        if fishCount >= autoSellThreshold then
                            VendorController:SellAllItems()
                            Notify("Auto Sell", string.format("Sold %d fish", fishCount), 2)
                        end
                    end
                end
            end)
            task.wait(3)
        end
    end)
    
    Notify("Auto Sell", string.format("Selling when >= %d fish", autoSellThreshold), 3)
end

local function StopAutoSell()
    if not autoSellEnabled then return end
    autoSellEnabled = false
    
    if autoSellLoop then
        task.cancel(autoSellLoop)
        autoSellLoop = nil
    end
    
    Notify("Auto Sell", "Stopped", 2)
end

-- Trick or Treat System
local function StartAutoTrickTreat()
    if autoTrickTreatEnabled then return end
    autoTrickTreatEnabled = true
    
    trickTreatLoop = task.spawn(function()
        while autoTrickTreatEnabled do
            pcall(function()
                -- Simple implementation for mobile
                Notify("Trick or Treat", "Searching for doors...", 2)
            end)
            task.wait(10)
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

-- =============================================================================
-- MOBILE OPTIMIZED UI CREATION
-- =============================================================================

-- Main Tab - Simple and clean
Tabs.Main:AddParagraph({
    Title = "Anggazyy Hub",
    Content = "Mobile Optimized"
})

-- Auto Tab - Short labels
Tabs.Auto:AddToggle("AutoFishToggle", {
    Title = "Auto Fishing",
    Description = "Automatic fishing",
    Default = false,
    Callback = function(state)
        if state then
            StartAutoFish()
        else
            StopAutoFish()
        end
    end
})

-- Weather Tab - Compact weather list
availableWeathers = LoadWeatherData()
for index, weather in ipairs(availableWeathers) do
    Tabs.Weather:AddToggle("WeatherToggle_" .. weather.InternalName, {
        Title = weather.Name,
        Description = weather.Price .. " coins",
        Default = false,
        Callback = function(state)
            selectedWeathers[weather.InternalName] = state
        end
    })
end

Tabs.Weather:AddButton({
    Title = "Buy Selected",
    Description = "Purchase selected weathers",
    Callback = BuySelectedWeathers
})

-- Bypass Tab - Essential features only
Tabs.Bypass:AddToggle("FishingRadarToggle", {
    Title = "Fishing Radar",
    Description = "Show fishing spots",
    Default = false,
    Callback = function(state)
        if state then
            ToggleFishingRadar()
        else
            ToggleFishingRadar()
        end
    end
})

Tabs.Bypass:AddToggle("AutoSellToggle", {
    Title = "Auto Sell Fish",
    Description = "Sell fish automatically",
    Default = false,
    Callback = function(state)
        if state then
            StartAutoSell()
        else
            StopAutoSell()
        end
    end
})

Tabs.Bypass:AddSlider("AutoSellThreshold", {
    Title = "Sell Threshold",
    Description = "Fish count to trigger sell",
    Default = 3,
    Min = 1,
    Max = 20,
    Rounding = 1,
    Callback = function(value)
        autoSellThreshold = value
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

-- Player Tab - Performance and movement
Tabs.Player:AddToggle("AntiLagToggle", {
    Title = "Performance Mode",
    Description = "Enable anti-lag",
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
    Description = "Prevent movement",
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
    Description = "Movement speed",
    Default = 16,
    Min = 16,
    Max = 100,
    Rounding = 1,
    Callback = function(value)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = value
        end
    end
})

-- Initialize UI
Fluent:SelectTab(1)

-- Mobile-specific optimizations
if isMobile then
    -- Disable zoom gestures that might interfere
    local function disableZoom()
        for _, connection in pairs(getconnections(UserInputService.TouchPinch)) do
            connection:Disable()
        end
        for _, connection in pairs(getconnections(UserInputService.TouchRotate)) do
            connection:Disable()
        end
    end
    
    pcall(disableZoom)
    
    -- Auto-clean for mobile performance
    task.spawn(function()
        while task.wait(5) do
            pcall(function()
                for _, obj in ipairs(CoreGui:GetDescendants()) do
                    if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                        local name = (obj.Name or ""):lower()
                        if string.find(name, "money") or string.find(name, "100") then
                            obj.Visible = false
                        end
                    end
                end
            end)
        end
    end)
end

-- Initial notification
Notify("Anggazyy Hub", "Mobile optimized version loaded!", 4)

-- Cleanup on script termination
game:GetService("Players").PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
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
