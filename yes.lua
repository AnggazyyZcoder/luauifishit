local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

--//////////////////////////////////////////////////////////////////////////////////
-- Anggazyy Hub - Fish It (FINAL) + Weather Machine + Trick or Treat
-- Fluent UI - Fixed Size for Mobile
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
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local LocalPlayer = Players.LocalPlayer

-- Variables
local autoFishEnabled = false
local antiLagEnabled = false
local savePositionEnabled = false
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
local isMobile = (game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled)

-- Fluent UI Window Creation with fixed size
local Window = Fluent:CreateWindow({
    Title = "Anggazyy Hub - Fish It",
    SubTitle = "Premium Automation System",
    TabWidth = isMobile and 70 or 90,
    Size = UDim2.fromOffset(400, 350), -- Fixed size, tidak terlalu besar
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.K
})

-- Tabs creation
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

-- =============================================================================
-- WEATHER MACHINE SYSTEM
-- =============================================================================

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
                    DisplayName = string.format("%s - %s Coins", event.Name or name, StringLibrary:AddCommas(event.WeatherMachinePrice))
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
        warn("⚠️ Failed to load weather data:", result)
        return {}
    end
end

local function PurchaseWeather(weatherName)
    local success, result = pcall(function()
        local Net = require(ReplicatedStorage.Packages.Net)
        local PurchaseWeatherEvent = Net:RemoteFunction("PurchaseWeatherEvent")
        local purchaseResult = PurchaseWeatherEvent:InvokeServer(weatherName)
        return purchaseResult
    end)
    
    return success, result
end

local function BuySelectedWeathers()
    if not next(selectedWeathers) then
        Notify("Weather Purchase", "No weathers selected!")
        return
    end
    
    local totalPurchases = 0
    local successfulPurchases = 0
    
    Notify("Weather Purchase", "Processing purchases...", 2)
    
    for weatherName, selected in pairs(selectedWeathers) do
        if selected then
            totalPurchases = totalPurchases + 1
            
            local weatherData
            for _, weather in ipairs(availableWeathers) do
                if weather.InternalName == weatherName then
                    weatherData = weather
                    break
                end
            end
            
            if weatherData then
                local success, result = PurchaseWeather(weatherName)
                if success and result then
                    successfulPurchases = successfulPurchases + 1
                    Notify("✅ Purchase Successful", string.format("Bought: %s", weatherData.Name))
                else
                    Notify("❌ Purchase Failed", string.format("Failed to buy: %s", weatherData.Name), 4)
                end
            end
            
            task.wait(0.5)
        end
    end
    
    selectedWeathers = {}
    Notify("Purchase Complete", string.format("Successfully purchased %d/%d weathers", successfulPurchases, totalPurchases), 4)
end

local function ToggleWeatherSelection(weatherIndex, state)
    if availableWeathers[weatherIndex] then
        local weather = availableWeathers[weatherIndex]
        selectedWeathers[weather.InternalName] = state
        Notify(state and "✅ Weather Selected" or "❌ Weather Deselected", string.format("%s %s", weather.Name, state and "selected" or "deselected"), 2)
    end
end

-- =============================================================================
-- TRICK OR TREAT SYSTEM
-- =============================================================================

local function GetSpecialDialogueRemote()
    local success, result = pcall(function()
        local Net = require(ReplicatedStorage.Packages.Net)
        local SpecialDialogueEvent = Net:RemoteFunction("SpecialDialogueEvent")
        return SpecialDialogueEvent
    end)
    
    if success then
        return result
    else
        warn("❌ Failed to load SpecialDialogueEvent:", result)
        return nil
    end
end

local function FindTrickOrTreatDoors()
    local doors = {}
    
    for _, door in pairs(workspace:GetDescendants()) do
        if door:IsA("Model") and door:FindFirstChild("Root") and door:FindFirstChild("Door") and door.Name then
            if door:GetAttribute("TrickOrTreatDoor") or string.find(door.Name, "House") then
                table.insert(doors, door)
            end
        end
    end
    
    return doors
end

local function KnockDoor(door)
    local success, result = pcall(function()
        local SpecialDialogueEvent = GetSpecialDialogueRemote()
        if not SpecialDialogueEvent then
            return false, "Remote not found"
        end
        
        local success, reward = SpecialDialogueEvent:InvokeServer(door.Name, "TrickOrTreatHouse")
        return success, reward
    end)
    
    return success, result
end

local function StartAutoTrickTreat()
    if autoTrickTreatEnabled then return end
    autoTrickTreatEnabled = true
    
    Notify("🎃 Auto Trick or Treat", "System activated - Knocking all doors...", 3)
    
    trickTreatLoop = task.spawn(function()
        while autoTrickTreatEnabled do
            local doors = FindTrickOrTreatDoors()
            
            if #doors > 0 then
                for _, door in ipairs(doors) do
                    if not autoTrickTreatEnabled then break end
                    
                    local success, result = KnockDoor(door)
                    if success then
                        if result == "Trick" then
                            print("[🎃] Trick dari " .. door.Name)
                        elseif result == "Treat" then
                            print("[🍬] Treat dari " .. door.Name .. " → +" .. tostring(result) .. " Candy Corns")
                        end
                    end
                    task.wait(0.5)
                end
            end
            
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
    
    Notify("🎃 Auto Trick or Treat", "System deactivated", 2)
end

local function ManualKnockAllDoors()
    local doors = FindTrickOrTreatDoors()
    
    if #doors == 0 then
        Notify("🎃 Trick or Treat", "No Trick or Treat doors found!")
        return
    end
    
    Notify("🎃 Manual Knock", string.format("Knocking %d doors...", #doors), 2)
    
    local successfulKnocks = 0
    local totalCandy = 0
    
    for _, door in ipairs(doors) do
        local success, result = KnockDoor(door)
        if success then
            successfulKnocks = successfulKnocks + 1
            if result == "Treat" then
                totalCandy = totalCandy + 1
            end
        end
        task.wait(0.5)
    end
    
    Notify("🎃 Knock Complete", string.format("Success: %d/%d doors | Candy: +%d", successfulKnocks, #doors, totalCandy), 4)
end

-- =============================================================================
-- AUTO FISHING SYSTEM
-- =============================================================================

local function StartAutoFish()
    if autoFishEnabled then return end
    autoFishEnabled = true
    Notify("Auto Fishing", "System activated successfully", 2)

    autoFishLoopThread = task.spawn(function()
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

-- =============================================================================
-- ANTI LAG SYSTEM
-- =============================================================================

local originalGraphicsSettings = {}

local function SaveOriginalGraphics()
    originalGraphicsSettings = {
        GraphicsQualityLevel = UserGameSettings.GraphicsQualityLevel,
        SavedQualityLevel = UserGameSettings.SavedQualityLevel,
        MasterVolume = Lighting.GlobalShadows,
        Brightness = Lighting.Brightness,
        FogEnd = Lighting.FogEnd,
        ShadowSoftness = Lighting.ShadowSoftness,
        EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale
    }
end

local function EnableAntiLag()
    if antiLagEnabled then return end
    
    SaveOriginalGraphics()
    antiLagEnabled = true
    
    pcall(function()
        UserGameSettings.GraphicsQualityLevel = 1
        UserGameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
        
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 999999
        Lighting.Brightness = 5
        Lighting.ShadowSoftness = 0
        Lighting.EnvironmentDiffuseScale = 1
        Lighting.EnvironmentSpecularScale = 0
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.ColorShift_Bottom = Color3.new(1, 1, 1)
        Lighting.ColorShift_Top = Color3.new(1, 1, 1)
        
        if workspace.Terrain then
            workspace.Terrain.Decoration = false
            workspace.Terrain.WaterReflectance = 0
            workspace.Terrain.WaterTransparency = 1
            workspace.Terrain.WaterWaveSize = 0
            workspace.Terrain.WaterWaveSpeed = 0
        end
        
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Part") or obj:IsA("MeshPart") or obj:IsA("UnionOperation") then
                if obj:FindFirstChildOfClass("Texture") then
                    obj:FindFirstChildOfClass("Texture"):Destroy()
                end
                if obj:FindFirstChildOfClass("Decal") then
                    obj:FindFirstChildOfClass("Decal"):Destroy()
                end
                obj.Material = Enum.Material.SmoothPlastic
                obj.BrickColor = BrickColor.new("White")
                obj.Reflectance = 0
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("Beam") or obj:IsA("Trail") then
                obj.Enabled = false
            elseif obj:IsA("Sound") and not obj:FindFirstAncestorWhichIsA("Player") then
                obj:Stop()
            end
        end
        
        settings().Rendering.QualityLevel = 1
    end)
    
    Notify("Ultra Anti Lag", "White texture mode enabled", 3)
end

local function DisableAntiLag()
    if not antiLagEnabled then return end
    antiLagEnabled = false
    
    pcall(function()
        if originalGraphicsSettings.GraphicsQualityLevel then
            UserGameSettings.GraphicsQualityLevel = originalGraphicsSettings.GraphicsQualityLevel
        end
        if originalGraphicsSettings.SavedQualityLevel then
            UserGameSettings.SavedQualityLevel = originalGraphicsSettings.SavedQualityLevel
        end
        if originalGraphicsSettings.MasterVolume ~= nil then
            Lighting.GlobalShadows = originalGraphicsSettings.MasterVolume
        end
        if originalGraphicsSettings.Brightness then
            Lighting.Brightness = originalGraphicsSettings.Brightness
        end
        if originalGraphicsSettings.FogEnd then
            Lighting.FogEnd = originalGraphicsSettings.FogEnd
        end
        if originalGraphicsSettings.ShadowSoftness then
            Lighting.ShadowSoftness = originalGraphicsSettings.ShadowSoftness
        end
        if originalGraphicsSettings.EnvironmentDiffuseScale then
            Lighting.EnvironmentDiffuseScale = originalGraphicsSettings.EnvironmentDiffuseScale
        end
        if originalGraphicsSettings.EnvironmentSpecularScale then
            Lighting.EnvironmentSpecularScale = originalGraphicsSettings.EnvironmentSpecularScale
        end
        
        if workspace.Terrain then
            workspace.Terrain.Decoration = true
            workspace.Terrain.WaterReflectance = 0.5
            workspace.Terrain.WaterTransparency = 0.5
            workspace.Terrain.WaterWaveSize = 0.5
            workspace.Terrain.WaterWaveSpeed = 10
        end
        
        Lighting.OutdoorAmbient = Color3.new(0.5, 0.5, 0.5)
        Lighting.Ambient = Color3.new(0.5, 0.5, 0.5)
        Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
        Lighting.ColorShift_Top = Color3.new(0, 0, 0)
        
        settings().Rendering.QualityLevel = 10
    end)
    
    Notify("Anti Lag", "Graphics settings restored", 3)
end

-- =============================================================================
-- POSITION MANAGEMENT
-- =============================================================================

local function SaveCurrentPosition()
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        lastSavedPosition = character.HumanoidRootPart.Position
        Notify("Position Saved", "Position saved successfully", 2)
        return true
    end
    return false
end

local function LoadSavedPosition()
    if not lastSavedPosition then
        Notify("Load Failed", "No position saved", 2)
        return false
    end
    
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.CFrame = CFrame.new(lastSavedPosition)
        Notify("Position Loaded", "Teleported to saved position", 2)
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
            
            if distance > 3 then
                character.HumanoidRootPart.CFrame = CFrame.new(lastSavedPosition)
            end
        end
    end)
    
    Notify("Position Lock", "Player position locked", 2)
end

local function StopLockPosition()
    if not lockPositionEnabled then return end
    lockPositionEnabled = false
    
    if lockPositionLoop then
        lockPositionLoop:Disconnect()
        lockPositionLoop = nil
    end
    
    Notify("Position Lock", "Player position unlocked", 2)
end

-- =============================================================================
-- BYPASS SYSTEM
-- =============================================================================

local function ToggleFishingRadar()
    local success, result = pcall(function()
        local Replion = require(ReplicatedStorage.Packages.Replion)
        local Net = require(ReplicatedStorage.Packages.Net)
        local UpdateFishingRadar = Net:RemoteFunction("UpdateFishingRadar")
        
        local Data = Replion.Client:WaitReplion("Data")
        if not Data then
            return false, "Data Replion tidak ditemukan!"
        end

        local currentState = Data:Get("RegionsVisible")
        local desiredState = not currentState

        local invokeSuccess = UpdateFishingRadar:InvokeServer(desiredState)
        
        if invokeSuccess then
            fishingRadarEnabled = desiredState
            return true, "Radar: " .. (desiredState and "ENABLED" or "DISABLED")
        else
            return false, "Failed to update radar"
        end
    end)
    
    if success then
        return true, result
    else
        return false, "Error: " .. tostring(result)
    end
end

local function StartFishingRadar()
    if fishingRadarEnabled then return end
    
    local success, message = ToggleFishingRadar()
    if success then
        fishingRadarEnabled = true
        Notify("Fishing Radar", message, 3)
    else
        Notify("Radar Error", message, 4)
    end
end

local function StopFishingRadar()
    if not fishingRadarEnabled then return end
    
    local success, message = ToggleFishingRadar()
    if success then
        fishingRadarEnabled = false
        Notify("Fishing Radar", message, 3)
    else
        Notify("Radar Error", message, 4)
    end
end

local function ToggleDivingGear()
    local success, result = pcall(function()
        local Net = require(ReplicatedStorage.Packages.Net)
        local Replion = require(ReplicatedStorage.Packages.Replion)
        local ItemUtility = require(ReplicatedStorage.Shared.ItemUtility)
        
        local DivingGear = ItemUtility.GetItemDataFromItemType("Gears", "Diving Gear")
        if not DivingGear then
            return false, "Diving Gear tidak ditemukan!"
        end

        local Data = Replion.Client:WaitReplion("Data")
        if not Data then
            return false, "Data Replion tidak ditemukan!"
        end

        local UnequipOxygenTank = Net:RemoteFunction("UnequipOxygenTank")
        local EquipOxygenTank = Net:RemoteFunction("EquipOxygenTank")

        local EquippedId = Data:Get("EquippedOxygenTankId")
        local isEquipped = EquippedId == DivingGear.Data.Id
        local success

        if isEquipped then
            success = UnequipOxygenTank:InvokeServer()
        else
            success = EquipOxygenTank:InvokeServer(DivingGear.Data.Id)
        end

        if success then
            divingGearEnabled = not isEquipped
            return true, "Diving Gear: " .. (not isEquipped and "ON" or "OFF")
        else
            return false, "Failed to toggle diving gear"
        end
    end)
    
    if success then
        return true, result
    else
        return false, "Error: " .. tostring(result)
    end
end

local function StartDivingGear()
    if divingGearEnabled then return end
    
    local success, message = ToggleDivingGear()
    if success then
        divingGearEnabled = true
        Notify("Diving Gear", message, 3)
    else
        Notify("Diving Gear Error", message, 4)
    end
end

local function StopDivingGear()
    if not divingGearEnabled then return end
    
    local success, message = ToggleDivingGear()
    if success then
        divingGearEnabled = false
        Notify("Diving Gear", message, 3)
    else
        Notify("Diving Gear Error", message, 4)
    end
end

local function ManualSellAllFish()
    local success, result = pcall(function()
        local VendorController = require(ReplicatedStorage.Controllers.VendorController)
        if VendorController and VendorController.SellAllItems then
            VendorController:SellAllItems()
            return true, "All fish sold successfully!"
        else
            return false, "VendorController not found"
        end
    end)
    
    if success then
        Notify("Manual Sell", result, 3)
    else
        Notify("Sell Error", result, 4)
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
                            Notify("Auto Sell", string.format("Sold %d fish automatically", fishCount), 2)
                        end
                    end
                end
            end)
            task.wait(2)
        end
    end)
    
    Notify("Auto Sell Started", string.format("Auto selling when fish count >= %d", autoSellThreshold), 3)
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

local function SetAutoSellThreshold(amount)
    if type(amount) == "number" and amount > 0 then
        autoSellThreshold = amount
        Notify("Auto Sell Threshold", string.format("Threshold set to %d fish", amount), 3)
        return true
    end
    return false
end

-- =============================================================================
-- UI CREATION - SEMUA FUNGSI DIPASTIKAN BERJALAN
-- =============================================================================

-- Main Tab
Tabs.Main:AddParagraph({
    Title = "Anggazyy Hub - Fish It",
    Content = "Premium fishing automation system"
})

-- Auto Tab
Tabs.Auto:AddToggle("AutoFishToggle", {
    Title = "Enable Auto Fishing",
    Description = "Automatically fish for you",
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

for index, weather in ipairs(availableWeathers) do
    Tabs.Weather:AddToggle("WeatherToggle_" .. weather.InternalName, {
        Title = weather.DisplayName,
        Description = "Select this weather for purchase",
        Default = false,
        Callback = function(state)
            ToggleWeatherSelection(index, state)
        end
    })
end

Tabs.Weather:AddButton({
    Title = "Buy Selected Weathers",
    Description = "Purchase all selected weather machines",
    Callback = BuySelectedWeathers
})

-- Bypass Tab
Tabs.Bypass:AddToggle("FishingRadarToggle", {
    Title = "Fishing Radar",
    Description = "Reveal fishing spots on map",
    Default = false,
    Callback = function(state)
        if state then
            StartFishingRadar()
        else
            StopFishingRadar()
        end
    end
})

Tabs.Bypass:AddToggle("DivingGearToggle", {
    Title = "Diving Gear",
    Description = "Automatically equip diving gear",
    Default = false,
    Callback = function(state)
        if state then
            StartDivingGear()
        else
            StopDivingGear()
        end
    end
})

Tabs.Bypass:AddToggle("AutoSellToggle", {
    Title = "Auto Sell Fish",
    Description = "Automatically sell fish when threshold reached",
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
    Description = "Number of fish to trigger auto sell",
    Default = 3,
    Min = 1,
    Max = 50,
    Rounding = 1,
    Callback = function(value)
        SetAutoSellThreshold(value)
    end
})

Tabs.Bypass:AddButton({
    Title = "Sell All Fish Now",
    Description = "Immediately sell all collected fish",
    Callback = ManualSellAllFish
})

Tabs.Bypass:AddToggle("AutoTrickTreatToggle", {
    Title = "Auto Trick or Treat",
    Description = "Automatically knock on Trick or Treat doors",
    Default = false,
    Callback = function(state)
        if state then
            StartAutoTrickTreat()
        else
            StopAutoTrickTreat()
        end
    end
})

Tabs.Bypass:AddButton({
    Title = "Knock All Doors Now",
    Description = "Manually knock on all Trick or Treat doors",
    Callback = ManualKnockAllDoors
})

-- Player Tab
Tabs.Player:AddToggle("AntiLagToggle", {
    Title = "Ultra Anti Lag",
    Description = "Enable white texture mode for maximum performance",
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
    Description = "Save current player position",
    Callback = SaveCurrentPosition
})

Tabs.Player:AddButton({
    Title = "Load Position",
    Description = "Teleport to saved position",
    Callback = LoadSavedPosition
})

Tabs.Player:AddToggle("LockPositionToggle", {
    Title = "Lock Position",
    Description = "Prevent player from moving from current position",
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
    Description = "Adjust player movement speed",
    Default = 16,
    Min = 16,
    Max = 200,
    Rounding = 1,
    Callback = function(value)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = value
        end
    end
})

Tabs.Player:AddSlider("JumpPower", {
    Title = "Jump Power",
    Description = "Adjust player jump height",
    Default = 50,
    Min = 50,
    Max = 350,
    Rounding = 1,
    Callback = function(value)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.JumpPower = value
        end
    end
})

-- Initialize UI
Fluent:SelectTab(1)

-- Initial Notification
Notify("Anggazyy Hub Ready", "All features loaded successfully!", 4)

-- Auto-clean money icons
task.spawn(function()
    while task.wait(1) do
        for _, obj in ipairs(CoreGui:GetDescendants()) do
            if obj and (obj:IsA("ImageLabel") or obj:IsA("ImageButton") or obj:IsA("TextLabel")) then
                local nameLower = (obj.Name or ""):lower()
                local textLower = (obj.Text or ""):lower()
                if string.find(nameLower, "money") or string.find(textLower, "money") or string.find(nameLower, "100") then
                    pcall(function()
                        obj.Visible = false
                        if obj:IsA("GuiObject") then
                            obj.Active = false
                            obj.ZIndex = 0
                        end
                    end)
                end
            end
        end
    end
end)
