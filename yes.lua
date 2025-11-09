--//////////////////////////////////////////////////////////////////////////////////
-- Anggazyy Hub - Fish It (FINAL) + Weather Machine + Trick or Treat + Blatant Fishing
-- WindUI Version - Modern, Mobile-Friendly Design
-- Author: Anggazyy (refactor)
--//////////////////////////////////////////////////////////////////////////////////

-- CONFIG: ubah sesuai kebutuhan
local AUTO_FISH_REMOTE_NAME = "UpdateAutoFishingState"
local NET_PACKAGES_FOLDER = "Packages"

-- Services & Variables
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local LocalPlayer = Players.LocalPlayer

-- Import required modules
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Net = require(ReplicatedStorage.Packages.Net)
local spr = require(ReplicatedStorage.Packages.spr)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Soundbook = require(ReplicatedStorage.Shared.Soundbook)
local GuiControl = require(ReplicatedStorage.Modules.GuiControl)
local HUDController = require(ReplicatedStorage.Controllers.HUDController)
local AnimationController = require(ReplicatedStorage.Controllers.AnimationController)
local TextNotificationController = require(ReplicatedStorage.Controllers.TextNotificationController)
local BlockedHumanoidStates = require(ReplicatedStorage.Shared.BlockedHumanoidStates)

-- UI Variables
local PlayerGui = LocalPlayer.PlayerGui
local Charge_upvr = PlayerGui:WaitForChild("Charge")
local Fishing_upvr = PlayerGui:WaitForChild("Fishing")
local Main_upvr = Fishing_upvr.Main
local CanvasGroup_upvr = Main_upvr.Display.CanvasGroup

-- Fishing status variables
local var17_upvw = nil -- Player Data
local var32_upvw = false -- Charge Started
local var34_upvw = false -- Is Stopped/Closing
local var35_upvw = nil -- Charge Start Time
local var36_upvw = nil -- Minigame UUID
local var37_upvw = nil -- Minigame State / Data
local var38_upvw = 0 -- Cooldown Time
local var40_upvw = nil -- Reel Sound Track
local var109_upvw = false -- Is Charging flag

local autoFishEnabled = false
local autoFishLoopThread = nil
local coordinateGui = nil
local statusParagraph = nil
local currentSelectedMap = nil

-- Player Configuration Variables
local antiLagEnabled = false
local savePositionEnabled = false
local lockPositionEnabled = false
local lastSavedPosition = nil
local lockPositionLoop = nil
local originalGraphicsSettings = {}

-- Bypass Variables
local fishingRadarEnabled = false
local divingGearEnabled = false
local autoSellEnabled = false
local autoSellThreshold = 3
local autoSellLoop = nil

-- Weather System Variables
local selectedWeathers = {}
local availableWeathers = {}

-- Trick or Treat Variables
local autoTrickTreatEnabled = false
local trickTreatLoop = nil

-- Blatant Fishing Variables
local isBlatantActive = false
local BLATANT_MODE_TROVE = nil
local originalFishingRodStarted = nil
local originalSendFishingRequestToServer = nil
local originalRequestChargeFishingRod = nil
local originalFishingStopped = nil
local FISHING_COMPLETED_REMOTE = nil
local RequestFishingMinigameStarted_Net = nil
local module_upvr = nil
local Net_upvr = nil
local Trove_upvr = nil
local Constants_upvr = nil

-- Blatant Fishing Configuration
local blatantReelDelay = 0.5  -- Default delay reel
local blatantFishingDelay = 0.0015  -- Default delay fishing

-- UI Configuration
local COLOR_ENABLED = Color3.fromRGB(76, 175, 80)  -- Green
local COLOR_DISABLED = Color3.fromRGB(244, 67, 54) -- Red
local COLOR_PRIMARY = Color3.fromRGB(103, 58, 183) -- Purple
local COLOR_SECONDARY = Color3.fromRGB(30, 30, 46)  -- Dark

-- Load WindUI
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/refs/heads/main/dist/main.lua"))()

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

-- Notification System
local function Notify(opts)
    pcall(function()
        WindUI:Notify({
            Title = opts.Title or "Notification",
            Content = opts.Content or "",
            Duration = opts.Duration or 3,
            Icon = opts.Icon or "info"
        })
    end)
end

-- =============================================================================
-- BLATANT FISHING SYSTEM - UPDATED WORKING VERSION
-- =============================================================================

local function InitializeBlatantFishing()
    local success, result = pcall(function()
        -- Load required modules for Blatant Fishing
        Net_upvr = require(ReplicatedStorage.Packages.Net)
        Trove_upvr = require(ReplicatedStorage.Packages.Trove)
        Constants_upvr = require(ReplicatedStorage.Shared.Constants)
        
        -- Get fishing module
        for _, module in pairs(ReplicatedStorage:GetDescendants()) do
            if module:IsA("ModuleScript") and (string.find(module.Name:lower(), "fishing") or string.find(module.Name:lower(), "controller")) then
                local modSuccess, modResult = pcall(function()
                    return require(module)
                end)
                if modSuccess and type(modResult) == "table" then
                    if modResult.RequestChargeFishingRod and modResult.FishingRodStarted then
                        module_upvr = modResult
                        break
                    end
                end
            end
        end
        
        if not module_upvr then
            local FishingController = ReplicatedStorage.Controllers:FindFirstChild("FishingController")
            if FishingController then
                module_upvr = require(FishingController)
            end
        end
        
        -- Get remote events/functions
        FISHING_COMPLETED_REMOTE = Net_upvr:RemoteEvent("FishingCompleted")
        RequestFishingMinigameStarted_Net = Net_upvr:RemoteFunction("RequestFishingMinigameStarted")
        
        -- Save original functions
        if module_upvr then
            originalFishingRodStarted = module_upvr.FishingRodStarted
            originalSendFishingRequestToServer = module_upvr.SendFishingRequestToServer
            originalRequestChargeFishingRod = module_upvr.RequestChargeFishingRod
            originalFishingStopped = module_upvr.FishingStopped
        end
        
        -- Initialize trove
        BLATANT_MODE_TROVE = Trove_upvr.new()
        
        return true
    end)
    
    if success then
        Notify({Title = "Blatant Fishing", Content = "System initialized successfully", Duration = 3})
        return true
    else
        Notify({Title = "Blatant Fishing Error", Content = "Failed to initialize: " .. tostring(result), Duration = 4})
        return false
    end
end

-- Fungsi yang menjalankan logika penyelesaian minigame secara instan (Blatant)
local function AutoFishComplete(rodData, minigameData)
    -- Blantant Mode: Delay reel (0 - 1.87)
    local reelDelay = blatantReelDelay
    if reelDelay > 0 then
        task.wait(reelDelay)
    end
    
    -- Fishing Complete: Langsung tembak RemoteEvent "FishingCompleted" ke server.
    pcall(function()
        FISHING_COMPLETED_REMOTE:FireServer() 
    end)
    
    print("⚡ Blatant Mode: Minigame Bypassed. Fish Retrieved.")

    -- Delay Fishing Complete sebelum loop Fast Fishing kembali melempar
    if blatantFishingDelay > 0 then
        task.wait(blatantFishingDelay)
    end
end

-- Fungsi HOOK untuk menimpa 'FishingRodStarted'
local function HookFishingRodStarted(rodData, minigameData)
    if isBlatantActive then
        -- Jika mode Blatant aktif, langsung selesaikan di thread terpisah
        task.spawn(function()
            AutoFishComplete(rodData, minigameData)
        end)
    else
        -- Jika tidak aktif, jalankan fungsi asli
        if originalFishingRodStarted then
            originalFishingRodStarted(rodData, minigameData)
        end
    end
end

-- =============================================================================
-- PERBAIKAN UTAMA: Hook FishingStopped untuk langsung casting lagi
-- =============================================================================

local function HookFishingStopped()
    if isBlatantActive then
        print("⚡ Blatant Mode: Fishing completed, preparing next cast...")
        
        -- Cleanup state variables
        var34_upvw = false
        var37_upvw = nil
        var36_upvw = nil
        
        -- Reset cooldown time untuk casting berikutnya
        var38_upvw = 0
        
        -- Small delay sebelum casting lagi
        task.wait(0.1)
        
        -- Langsung casting lagi tanpa melalui charging
        if module_upvr and module_upvr.RequestChargeFishingRod then
            task.spawn(function()
                -- Tunggu sebentar untuk memastikan cleanup selesai
                task.wait(0.2)
                
                -- Cast fishing rod lagi
                local mousePos = Vector2.new(0, 0)
                local skipCharge = true
                
                print("⚡ Blatant Mode: Auto recasting...")
                module_upvr:RequestChargeFishingRod(mousePos, nil, skipCharge)
            end)
        end
    else
        -- Normal behavior
        if originalFishingStopped then
            originalFishingStopped()
        end
    end
end

-- Fungsi untuk mendapatkan mouse position yang aman
local function GetSafeMousePosition()
    local UserInputService = game:GetService("UserInputService")
    local CurrentCamera = workspace.CurrentCamera
    
    if UserInputService.MouseEnabled then
        return UserInputService:GetMouseLocation()
    else
        local viewportSize = CurrentCamera.ViewportSize
        return Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    end
end

-- Approach 1: Menggunakan RequestChargeFishingRod dengan bypass
local function BlatantCastMethod1()
    if not module_upvr or not module_upvr.RequestChargeFishingRod then
        return false
    end
    
    local success, result = pcall(function()
        -- Set konfirmasi untuk bypass user input
        _G.confirmFishingInput = function() return true end
        
        local mousePos = GetSafeMousePosition()
        local skipCharge = true
        
        -- Panggil RequestChargeFishingRod dengan parameter skip charge
        local castResult = module_upvr:RequestChargeFishingRod(mousePos, nil, skipCharge)
        
        _G.confirmFishingInput = nil
        return castResult
    end)
    
    return success
end

-- Approach 2: Direct server call
local function BlatantCastMethod2()
    if not RequestFishingMinigameStarted_Net then
        return false
    end
    
    local success, result = pcall(function()
        -- Get character position
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            return false, "No character found"
        end
        
        local throwPosition = character.HumanoidRootPart.Position + Vector3.new(0, -1, 10)
        local power = 0.5
        local castTime = workspace:GetServerTimeNow()
        
        local serverSuccess, serverResult = RequestFishingMinigameStarted_Net:InvokeServer(
            throwPosition.Y,
            power, 
            castTime
        )
        
        if serverSuccess then
            -- Trigger FishingRodStarted manually
            if module_upvr and module_upvr.FishingRodStarted then
                module_upvr:FishingRodStarted(serverResult)
            end
            return true
        else
            return false, tostring(serverResult)
        end
    end)
    
    return success
end

-- Approach 3: Menggunakan SendFishingRequestToServer langsung
local function BlatantCastMethod3()
    if not module_upvr or not module_upvr.SendFishingRequestToServer then
        return false
    end
    
    local success, result = pcall(function()
        local mousePos = GetSafeMousePosition()
        local power = 0.5
        local skipCharge = true
        
        local sendSuccess, sendResult = module_upvr:SendFishingRequestToServer(mousePos, power, skipCharge)
        return sendSuccess
    end)
    
    return success
end

-- Main blatant casting function yang mencoba semua method
local function BlatantCastFishingRod()
    -- Coba method 1: RequestChargeFishingRod dengan bypass
    local success = BlatantCastMethod1()
    if success then
        print("✅ Blatant Cast: Method 1 successful")
        return true
    end
    
    -- Coba method 2: Direct server call
    success = BlatantCastMethod2()
    if success then
        print("✅ Blatant Cast: Method 2 successful")
        return true
    end
    
    -- Coba method 3: SendFishingRequestToServer langsung
    success = BlatantCastMethod3()
    if success then
        print("✅ Blatant Cast: Method 3 successful")
        return true
    end
    
    print("❌ Blatant Cast: All methods failed")
    return false
end

-- =============================================================================
-- PERBAIKAN UTAMA: BlatantFishingLoop yang menggunakan continuous casting
-- =============================================================================

local function BlatantFishingLoop()
    while isBlatantActive do
        local castSuccess = BlatantCastFishingRod()
        
        if not castSuccess then
            print("🔄 Retrying cast...")
            task.wait(0.5) -- Delay lebih lama jika gagal
        else
            -- Tunggu sampai fishing selesai sebelum casting lagi
            -- HookFishingStopped akan menangani casting berikutnya
            local waitStart = tick()
            while isBlatantActive and (tick() - waitStart) < 10 do -- Max 10 detik wait
                task.wait(0.1)
                -- Jika fishing sudah selesai (state direset), break dan casting lagi
                if not var36_upvw and not var37_upvw then
                    break
                end
            end
            
            -- Jika masih aktif, casting lagi
            if isBlatantActive then
                print("⚡ Blatant Mode: Preparing next cast...")
                task.wait(blatantFishingDelay)
            end
        end
    end
end

-- Hook untuk RequestChargeFishingRod
local function HookRequestChargeFishingRod(arg1, arg2, arg3)
    if isBlatantActive then
        print("⚡ Blatant Mode: Fast casting via RequestChargeFishingRod")
        
        -- Di Blatant Mode, gunakan parameter untuk skip charging
        local mousePos = arg1 or GetSafeMousePosition()
        local skipCharge = true
        
        return originalRequestChargeFishingRod(mousePos, arg2, skipCharge)
    else
        return originalRequestChargeFishingRod(arg1, arg2, arg3)
    end
end

-- Hook untuk SendFishingRequestToServer
local function HookSendFishingRequestToServer(mousePosition, power, skipCharge)
    if isBlatantActive then
        print("⚡ Blatant Mode: SendFishingRequestToServer with forced parameters")
        return originalSendFishingRequestToServer(mousePosition, 0.5, true)
    else
        return originalSendFishingRequestToServer(mousePosition, power, skipCharge)
    end
end

-- Fungsi untuk mengatur delay reel
local function SetBlatantReelDelay(delay)
    if type(delay) == "number" and delay >= 0 and delay <= 1.87 then
        blatantReelDelay = delay
        Notify({
            Title = "Blatant Fishing", 
            Content = string.format("Reel delay set to %.4f seconds", delay),
            Duration = 3
        })
        return true
    end
    return false
end

-- Fungsi untuk mengatur delay fishing
local function SetBlatantFishingDelay(delay)
    if type(delay) == "number" and delay >= 0 and delay <= 5 then
        blatantFishingDelay = delay
        Notify({
            Title = "Blatant Fishing", 
            Content = string.format("Fishing delay (loop) set to %.4f seconds", delay),
            Duration = 3
        })
        return true
    end
    return false
end

-- Fungsi publik untuk mengaktifkan/menonaktifkan Blatant Mode
local function ToggleBlatantMode(enable)
    if enable == isBlatantActive then return end
    
    if enable then
        -- Initialize system if not already initialized
        if not module_upvr or not FISHING_COMPLETED_REMOTE then
            if not InitializeBlatantFishing() then
                return false
            end
        end
        
        isBlatantActive = true
        print("✅ Blantant Mode (Fast Fishing): ENABLED.")
        
        -- Terapkan Hook pada fungsi-fungsi fishing
        if module_upvr then
            if module_upvr.FishingRodStarted ~= HookFishingRodStarted then
                module_upvr.FishingRodStarted = HookFishingRodStarted
            end
            
            if module_upvr.RequestChargeFishingRod and module_upvr.RequestChargeFishingRod ~= HookRequestChargeFishingRod then
                module_upvr.RequestChargeFishingRod = HookRequestChargeFishingRod
            end
            
            if module_upvr.SendFishingRequestToServer and module_upvr.SendFishingRequestToServer ~= HookSendFishingRequestToServer then
                module_upvr.SendFishingRequestToServer = HookSendFishingRequestToServer
            end
            
            -- HOOK BARU: FishingStopped untuk auto recast
            if module_upvr.FishingStopped and module_upvr.FishingStopped ~= HookFishingStopped then
                module_upvr.FishingStopped = HookFishingStopped
            end
            
            -- Tambahkan fungsi pembersihan ke Trove
            if BLATANT_MODE_TROVE then
                BLATANT_MODE_TROVE:Add(function() 
                    if module_upvr then
                        if originalFishingRodStarted then
                            module_upvr.FishingRodStarted = originalFishingRodStarted 
                        end
                        if originalRequestChargeFishingRod then
                            module_upvr.RequestChargeFishingRod = originalRequestChargeFishingRod
                        end
                        if originalSendFishingRequestToServer then
                            module_upvr.SendFishingRequestToServer = originalSendFishingRequestToServer
                        end
                        if originalFishingStopped then
                            module_upvr.FishingStopped = originalFishingStopped
                        end
                    end
                end)
            end
        end
        
        -- Jalankan loop Fast Fishing
        if BLATANT_MODE_TROVE then
            BLATANT_MODE_TROVE:Add(task.spawn(BlatantFishingLoop))
        end
        
        Notify({Title = "⚡ Blatant Fishing", Content = "Fast fishing mode activated - Continuous casting without charging", Duration = 3})
        
    else
        isBlatantActive = false
        print("❌ Blantant Mode (Fast Fishing): DISABLED. Cleaning up...")
        
        -- Cleanup
        if BLATANT_MODE_TROVE then
            BLATANT_MODE_TROVE:Clean()
        end
        
        -- Restore original functions
        if module_upvr then
            if originalFishingRodStarted then
                module_upvr.FishingRodStarted = originalFishingRodStarted
            end
            if originalRequestChargeFishingRod then
                module_upvr.RequestChargeFishingRod = originalRequestChargeFishingRod
            end
            if originalSendFishingRequestToServer then
                module_upvr.SendFishingRequestToServer = originalSendFishingRequestToServer
            end
            if originalFishingStopped then
                module_upvr.FishingStopped = originalFishingStopped
            end
        end
        
        Notify({Title = "Blatant Fishing", Content = "Fast fishing mode deactivated", Duration = 3})
    end
    
    return true
end

-- Manual fishing function untuk testing
local function ManualBlatantFish()
    if not isBlatantActive then
        Notify({Title = "Blatant Fishing", Content = "Please enable Blatant Mode first", Duration = 3})
        return
    end
    
    pcall(function()
        local success = BlatantCastFishingRod()
        if success then
            Notify({Title = "⚡ Manual Cast", Content = "Casting fishing rod instantly...", Duration = 2})
        else
            Notify({Title = "❌ Manual Cast Failed", Content = "Failed to cast fishing rod", Duration = 2})
        end
    end)
end

-- Network Communication untuk Auto Fishing biasa
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
        -- Load required modules
        local EventUtility = require(ReplicatedStorage.Shared.EventUtility)
        local StringLibrary = require(ReplicatedStorage.Shared.StringLibrary)
        local Events = require(ReplicatedStorage.Events)
        
        local weatherList = {}
        
        -- Iterate through all events to find weather machines
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
        
        -- Sort by price (ascending)
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
        -- Load required modules
        local Net = require(ReplicatedStorage.Packages.Net)
        local PurchaseWeatherEvent = Net:RemoteFunction("PurchaseWeatherEvent")
        
        -- Purchase the weather
        local purchaseResult = PurchaseWeatherEvent:InvokeServer(weatherName)
        return purchaseResult
    end)
    
    return success, result
end

local function BuySelectedWeathers()
    if not next(selectedWeathers) then
        Notify({
            Title = "Weather Purchase",
            Content = "No weathers selected!",
            Duration = 3
        })
        return
    end
    
    local totalPurchases = 0
    local successfulPurchases = 0
    
    Notify({
        Title = "Weather Purchase",
        Content = "Processing purchases...",
        Duration = 2
    })
    
    for weatherName, selected in pairs(selectedWeathers) do
        if selected then
            totalPurchases = totalPurchases + 1
            
            -- Find weather data
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
                    Notify({
                        Title = "✅ Purchase Successful",
                        Content = string.format("Bought: %s", weatherData.Name),
                        Duration = 3
                    })
                else
                    Notify({
                        Title = "❌ Purchase Failed",
                        Content = string.format("Failed to buy: %s", weatherData.Name),
                        Duration = 4
                    })
                end
            end
            
            -- Small delay between purchases
            task.wait(0.5)
        end
    end
    
    -- Clear selection after purchase
    selectedWeathers = {}
    
    Notify({
        Title = "Purchase Complete",
        Content = string.format("Successfully purchased %d/%d weathers", successfulPurchases, totalPurchases),
        Duration = 4
    })
end

local function RefreshWeatherList()
    availableWeathers = LoadWeatherData()
    
    -- Create display options for dropdown
    local weatherOptions = {}
    for _, weather in ipairs(availableWeathers) do
        table.insert(weatherOptions, weather.DisplayName)
    end
    
    return weatherOptions, availableWeathers
end

local function ToggleWeatherSelection(weatherIndex, state)
    if availableWeathers[weatherIndex] then
        local weather = availableWeathers[weatherIndex]
        selectedWeathers[weather.InternalName] = state
        
        Notify({
            Title = state and "✅ Weather Selected" or "❌ Weather Deselected",
            Content = string.format("%s %s", weather.Name, state and "selected" or "deselected"),
            Duration = 2
        })
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
    
    Notify({
        Title = "🎃 Auto Trick or Treat",
        Content = "System activated - Knocking all doors...",
        Duration = 3
    })
    
    trickTreatLoop = task.spawn(function()
        while autoTrickTreatEnabled do
            local doors = FindTrickOrTreatDoors()
            
            if #doors > 0 then
                Notify({
                    Title = "🎃 Trick or Treat",
                    Content = string.format("Found %d doors, knocking...", #doors),
                    Duration = 2
                })
                
                for _, door in ipairs(doors) do
                    if not autoTrickTreatEnabled then break end
                    
                    local success, result = KnockDoor(door)
                    if success then
                        if result == "Trick" then
                            print("[🎃] Trick dari " .. door.Name)
                        elseif result == "Treat" then
                            print("[🍬] Treat dari " .. door.Name .. " → +" .. tostring(result) .. " Candy Corns")
                        else
                            print("[❌] Gagal interaksi dengan " .. door.Name)
                        end
                    else
                        print("[❌] Error knocking " .. door.Name .. ": " .. tostring(result))
                    end
                    
                    task.wait(0.5) -- Jeda biar gak spam server
                end
            else
                print("[🔍] Tidak ada Trick or Treat doors yang ditemukan")
            end
            
            -- Tunggu sebelum scan ulang
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
    
    Notify({
        Title = "🎃 Auto Trick or Treat",
        Content = "System deactivated",
        Duration = 2
    })
end

local function ManualKnockAllDoors()
    local doors = FindTrickOrTreatDoors()
    
    if #doors == 0 then
        Notify({
            Title = "🎃 Trick or Treat",
            Content = "No Trick or Treat doors found!",
            Duration = 3
        })
        return
    end
    
    Notify({
        Title = "🎃 Manual Knock",
        Content = string.format("Knocking %d doors...", #doors),
        Duration = 2
    })
    
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
    
    Notify({
        Title = "🎃 Knock Complete",
        Content = string.format("Success: %d/%d doors | Candy: +%d", successfulKnocks, #doors, totalCandy),
        Duration = 4
    })
end

-- Auto Fishing System
local function StartAutoFish()
    if autoFishEnabled then return end
    autoFishEnabled = true
    Notify({Title = "Auto Fishing", Content = "System activated successfully", Duration = 2})

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
    Notify({Title = "Auto Fishing", Content = "System deactivated", Duration = 2})
    
    pcall(function()
        SafeInvokeAutoFishing(false)
    end)
end

-- =============================================================================
-- ULTRA ANTI LAG SYSTEM - WHITE TEXTURE MODE
-- =============================================================================

-- Save original graphics settings
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

-- Ultra Anti Lag System - White Texture Mode
local function EnableAntiLag()
    if antiLagEnabled then return end
    
    SaveOriginalGraphics()
    antiLagEnabled = true
    
    -- Extreme graphics optimization with white textures
    pcall(function()
        -- Graphics quality settings
        UserGameSettings.GraphicsQualityLevel = 1
        UserGameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
        
        -- Lighting optimization - Bright white environment
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 999999
        Lighting.Brightness = 5  -- Extra bright
        Lighting.ShadowSoftness = 0
        Lighting.EnvironmentDiffuseScale = 1
        Lighting.EnvironmentSpecularScale = 0
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)  -- Pure white ambient
        Lighting.Ambient = Color3.new(1, 1, 1)  -- Pure white
        Lighting.ColorShift_Bottom = Color3.new(1, 1, 1)
        Lighting.ColorShift_Top = Color3.new(1, 1, 1)
        
        -- Terrain optimization - White terrain
        if workspace.Terrain then
            workspace.Terrain.Decoration = false
            workspace.Terrain.WaterReflectance = 0
            workspace.Terrain.WaterTransparency = 1
            workspace.Terrain.WaterWaveSize = 0
            workspace.Terrain.WaterWaveSpeed = 0
        end
        
        -- Make all parts white and disable effects
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Part") or obj:IsA("MeshPart") or obj:IsA("UnionOperation") then
                -- Set all parts to white
                if obj:FindFirstChildOfClass("Texture") then
                    obj:FindFirstChildOfClass("Texture"):Destroy()
                end
                if obj:FindFirstChildOfClass("Decal") then
                    obj:FindFirstChildOfClass("Decal"):Destroy()
                end
                obj.Material = Enum.Material.SmoothPlastic
                obj.BrickColor = BrickColor.new("White")
                obj.Reflectance = 0
            elseif obj:IsA("ParticleEmitter") then
                obj.Enabled = false
            elseif obj:IsA("Fire") then
                obj.Enabled = false
            elseif obj:IsA("Smoke") then
                obj.Enabled = false
            elseif obj:IsA("Sparkles") then
                obj.Enabled = false
            elseif obj:IsA("Beam") then
                obj.Enabled = false
            elseif obj:IsA("Trail") then
                obj.Enabled = false
            elseif obj:IsA("Sound") and not obj:FindFirstAncestorWhichIsA("Player") then
                obj:Stop()
            end
        end
        
        -- Reduce texture quality to minimum
        settings().Rendering.QualityLevel = 1
    end)
    
    Notify({Title = "Ultra Anti Lag", Content = "White texture mode enabled - Maximum performance", Duration = 3})
end

local function DisableAntiLag()
    if not antiLagEnabled then return end
    antiLagEnabled = false
    
    -- Restore original graphics settings
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
        
        -- Restore terrain
        if workspace.Terrain then
            workspace.Terrain.Decoration = true
            workspace.Terrain.WaterReflectance = 0.5
            workspace.Terrain.WaterTransparency = 0.5
            workspace.Terrain.WaterWaveSize = 0.5
            workspace.Terrain.WaterWaveSpeed = 10
        end
        
        -- Restore lighting
        Lighting.OutdoorAmbient = Color3.new(0.5, 0.5, 0.5)
        Lighting.Ambient = Color3.new(0.5, 0.5, 0.5)
        Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
        Lighting.ColorShift_Top = Color3.new(0, 0, 0)
        
        -- Restore texture quality
        settings().Rendering.QualityLevel = 10
    end)
    
    Notify({Title = "Anti Lag", Content = "Graphics settings restored", Duration = 3})
end

-- Position Management System
local function SaveCurrentPosition()
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        lastSavedPosition = character.HumanoidRootPart.Position
        Notify({
            Title = "Position Saved", 
            Content = string.format("Position saved successfully"),
            Duration = 2
        })
        return true
    end
    return false
end

local function LoadSavedPosition()
    if not lastSavedPosition then
        Notify({Title = "Load Failed", Content = "No position saved", Duration = 2})
        return false
    end
    
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.CFrame = CFrame.new(lastSavedPosition)
        Notify({Title = "Position Loaded", Content = "Teleported to saved position", Duration = 2})
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
    
    Notify({Title = "Position Lock", Content = "Player position locked", Duration = 2})
end

local function StopLockPosition()
    if not lockPositionEnabled then return end
    lockPositionEnabled = false
    
    if lockPositionLoop then
        lockPositionLoop:Disconnect()
        lockPositionLoop = nil
    end
    
    Notify({Title = "Position Lock", Content = "Player position unlocked", Duration = 2})
end

-- =============================================================================
-- BYPASS SYSTEM - FISHING RADAR, DIVING GEAR & AUTO SELL
-- =============================================================================

-- Fishing Radar System
local function ToggleFishingRadar()
    local success, result = pcall(function()
        -- Load required modules
        local Replion = require(ReplicatedStorage.Packages.Replion)
        local Net = require(ReplicatedStorage.Packages.Net)
        local UpdateFishingRadar = Net:RemoteFunction("UpdateFishingRadar")
        
        -- Get player data
        local Data = Replion.Client:WaitReplion("Data")
        if not Data then
            return false, "Data Replion tidak ditemukan!"
        end

        -- Get current radar state
        local currentState = Data:Get("RegionsVisible")
        local desiredState = not currentState

        -- Invoke server to update radar
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
        Notify({Title = "Fishing Radar", Content = message, Duration = 3})
    else
        Notify({Title = "Radar Error", Content = message, Duration = 4})
    end
end

local function StopFishingRadar()
    if not fishingRadarEnabled then return end
    
    local success, message = ToggleFishingRadar()
    if success then
        fishingRadarEnabled = false
        Notify({Title = "Fishing Radar", Content = message, Duration = 3})
    else
        Notify({Title = "Radar Error", Content = message, Duration = 4})
    end
end

-- Diving Gear System
local function ToggleDivingGear()
    local success, result = pcall(function()
        -- Load required modules
        local Net = require(ReplicatedStorage.Packages.Net)
        local Replion = require(ReplicatedStorage.Packages.Replion)
        local ItemUtility = require(ReplicatedStorage.Shared.ItemUtility)
        
        -- Get diving gear data
        local DivingGear = ItemUtility.GetItemDataFromItemType("Gears", "Diving Gear")
        if not DivingGear then
            return false, "Diving Gear tidak ditemukan!"
        end

        -- Get player data
        local Data = Replion.Client:WaitReplion("Data")
        if not Data then
            return false, "Data Replion tidak ditemukan!"
        end

        -- Get remote functions
        local UnequipOxygenTank = Net:RemoteFunction("UnequipOxygenTank")
        local EquipOxygenTank = Net:RemoteFunction("EquipOxygenTank")

        -- Check current equipment state
        local EquippedId = Data:Get("EquippedOxygenTankId")
        local isEquipped = EquippedId == DivingGear.Data.Id
        local success

        -- Toggle equipment
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
        Notify({Title = "Diving Gear", Content = message, Duration = 3})
    else
        Notify({Title = "Diving Gear Error", Content = message, Duration = 4})
    end
end

local function StopDivingGear()
    if not divingGearEnabled then return end
    
    local success, message = ToggleDivingGear()
    if success then
        divingGearEnabled = false
        Notify({Title = "Diving Gear", Content = message, Duration = 3})
    else
        Notify({Title = "Diving Gear Error", Content = message, Duration = 4})
    end
end

-- Auto Sell System
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
        Notify({Title = "Manual Sell", Content = result, Duration = 3})
    else
        Notify({Title = "Sell Error", Content = result, Duration = 4})
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
                            Notify({
                                Title = "Auto Sell", 
                                Content = string.format("Sold %d fish automatically", fishCount),
                                Duration = 2
                            })
                        end
                    end
                end
            end)
            task.wait(2) -- Check every 2 seconds
        end
    end)
    
    Notify({
        Title = "Auto Sell Started", 
        Content = string.format("Auto selling when fish count >= %d", autoSellThreshold),
        Duration = 3
    })
end

local function StopAutoSell()
    if not autoSellEnabled then return end
    autoSellEnabled = false
    
    if autoSellLoop then
        task.cancel(autoSellLoop)
        autoSellLoop = nil
    end
    
    Notify({Title = "Auto Sell", Content = "Auto sell stopped", Duration = 2})
end

local function SetAutoSellThreshold(amount)
    if type(amount) == "number" and amount > 0 then
        autoSellThreshold = amount
        Notify({
            Title = "Auto Sell Threshold", 
            Content = string.format("Threshold set to %d fish", amount),
            Duration = 3
        })
        return true
    end
    return false
end

-- Auto Radar Toggle with safety
local function SafeToggleRadar()
    local success, message = ToggleFishingRadar()
    if success then
        Notify({Title = "Fishing Radar", Content = message, Duration = 3})
    else
        Notify({Title = "Radar Error", Content = message, Duration = 4})
    end
end

-- Auto Diving Gear Toggle with safety
local function SafeToggleDivingGear()
    local success, message = ToggleDivingGear()
    if success then
        Notify({Title = "Diving Gear", Content = message, Duration = 3})
    else
        Notify({Title = "Diving Gear Error", Content = message, Duration = 4})
    end
end

-- Coordinate Display System
local function CreateCoordinateDisplay()
    if coordinateGui and coordinateGui.Parent then coordinateGui:Destroy() end
    
    local sg = Instance.new("ScreenGui")
    sg.Name = "Anggazyy_Coordinates"
    sg.ResetOnSpawn = false
    sg.Parent = CoreGui

    local frame = Instance.new("Frame", sg)
    frame.Size = UDim2.new(0, 220, 0, 40)
    frame.Position = UDim2.new(0.5, -110, 0, 15)
    frame.BackgroundColor3 = COLOR_SECONDARY
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0.3, 0)
    
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = COLOR_PRIMARY
    stroke.Thickness = 1.6

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -12, 1, 0)
    label.Position = UDim2.new(0, 6, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(235, 235, 245)
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 14
    label.Text = "X: 0 | Y: 0 | Z: 0"
    label.TextXAlignment = Enum.TextXAlignment.Left

    coordinateGui = sg

    task.spawn(function()
        while coordinateGui and coordinateGui.Parent do
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local pos = char.HumanoidRootPart.Position
                label.Text = string.format("X: %d | Y: %d | Z: %d", math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z))
            else
                label.Text = "X: - | Y: - | Z: -"
            end
            task.wait(0.12)
        end
    end)
end

local function DestroyCoordinateDisplay()
    if coordinateGui and coordinateGui.Parent then
        pcall(function() coordinateGui:Destroy() end)
        coordinateGui = nil
    end
end

-- =============================================================================
-- WINDUI MAIN WINDOW CREATION
-- =============================================================================

-- Create Main Window
local Window = WindUI:CreateWindow({
    Title = "Anggazyy Hub - Fish It",
    Author = "by Anggazyy • Premium Automation",
    Folder = "AnggazyyHub",
    Icon = "fish",
    NewElements = true,
    
    HideSearchBar = false,
    
    OpenButton = {
        Title = "Open Anggazyy Hub",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 3,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        
        Color = ColorSequence.new(
            Color3.fromHex("#6b31ff"), 
            Color3.fromHex("#30a2ff")
        )
    }
})

-- Add version tag
Window:Tag({
    Title = "v2.0",
    Icon = "github",
    Color = Color3.fromHex("#6b31ff")
})

-- ========== ABOUT US TAB ==========
local AboutTab = Window:Tab({
    Title = "About Us",
    Icon = "info",
})

local AboutSection = AboutTab:Section({
    Title = "About Anggazyy Hub",
})

AboutSection:Image({
    Image = "https://files.catbox.moe/of2fla.jpg",
    AspectRatio = "16:9",
    Radius = 9,
})

AboutSection:Space({ Columns = 3 })

AboutSection:Section({
    Title = "What Is Anggazyy Hub?",
    TextSize = 24,
    FontWeight = Enum.FontWeight.SemiBold,
})

AboutSection:Space()

AboutSection:Section({
    Title = [[Anggazyy Hub adalah script premium yang dirancang khusus untuk game Fish It di Roblox. 
Dikembangkan oleh Anggazyy dengan fokus pada automasi dan optimasi gameplay.

Fitur Utama:
• Auto Fishing System - Automatisasi memancing yang cerdas
• Weather Machine - Sistem pembelian dan manajemen cuaca
• Bypass Features - Fitur canggih untuk meningkatkan gameplay
• Player Configuration - Optimasi performa dan kontrol karakter
• Mobile-Friendly UI - Antarmuka yang responsif untuk semua device

Dibangun dengan teknologi terbaru untuk memberikan pengalaman gaming yang optimal dan efisien.]],
    TextSize = 16,
    TextTransparency = 0.35,
    FontWeight = Enum.FontWeight.Medium,
})

AboutTab:Space({ Columns = 4 })

-- ========== AUTO SYSTEM TAB ==========
local AutoTab = Window:Tab({
    Title = "Automation",
    Icon = "fish",
})

AutoTab:Section({
    Title = "Auto Fishing System",
    TextSize = 20,
    FontWeight = Enum.FontWeight.SemiBold,
})

AutoTab:Space()

AutoTab:Toggle({
    Title = "Enable Auto Fishing",
    Desc = "Automated fishing with server communication",
    Flag = "AutoFishToggle",
    Default = false,
    Callback = function(state)
        if state then
            StartAutoFish()
        else
            StopAutoFish()
        end
    end
})

AutoTab:Space()

-- Blatant Fishing Section
AutoTab:Section({
    Title = "⚡ Blatant Fishing",
    TextSize = 20,
    FontWeight = Enum.FontWeight.SemiBold,
})

AutoTab:Toggle({
    Title = "Blatant Mode",
    Desc = "Fast fishing with minigame bypass",
    Flag = "BlatantModeToggle",
    Default = false,
    Callback = function(state)
        ToggleBlatantMode(state)
    end
})

AutoTab:Slider({
    Title = "Delay Reel",
    Desc = "Delay before reeling fish (0 - 1.87)",
    Flag = "BlatantReelDelay",
    Step = 0.01,
    Value = {
        Min = 0,
        Max = 1.87,
        Default = 0.5,
    },
    Callback = function(value)
        SetBlatantReelDelay(value)
    end
})

AutoTab:Slider({
    Title = "Delay Fishing",
    Desc = "Delay between fishing attempts (Fast Loop)",
    Flag = "BlatantFishingDelay",
    Step = 0.001,
    Value = {
        Min = 0,
        Max = 0.1,
        Default = 0.0015,
    },
    Callback = function(value)
        SetBlatantFishingDelay(value)
    end
})

AutoTab:Button({
    Title = "Initialize Blatant System",
    Icon = "zap",
    Callback = function()
        InitializeBlatantFishing()
    end
})

AutoTab:Button({
    Title = "Manual Cast",
    Icon = "fishing-rod",
    Callback = ManualBlatantFish
})

AutoTab:Space()

-- ========== WEATHER MACHINE TAB ==========
local WeatherTab = Window:Tab({
    Title = "Weather Machine",
    Icon = "cloud",
})

WeatherTab:Section({
    Title = "Weather Machine",
    Desc = "Purchase and activate different weather events",
})

-- Load weather data initially
availableWeathers = LoadWeatherData()

-- Weather Selection Toggles
for index, weather in ipairs(availableWeathers) do
    WeatherTab:Toggle({
        Title = weather.DisplayName,
        Flag = "WeatherToggle_" .. weather.InternalName,
        Default = false,
        Callback = function(state)
            ToggleWeatherSelection(index, state)
        end
    })
    
    if index < #availableWeathers then
        WeatherTab:Space()
    end
end

WeatherTab:Space({ Columns = 2 })

WeatherTab:Button({
    Title = "Buy Selected Weathers",
    Icon = "shopping-cart",
    Justify = "Center",
    Callback = BuySelectedWeathers
})

WeatherTab:Button({
    Title = "Refresh Weather List",
    Icon = "refresh-cw",
    Justify = "Center",
    Callback = function()
        local newOptions, newWeathers = RefreshWeatherList()
        Notify({
            Title = "Weather List Updated",
            Content = string.format("Loaded %d available weathers", #newWeathers),
            Duration = 3
        })
    end
})

-- ========== BYPASS TAB ==========
local BypassTab = Window:Tab({
    Title = "Bypass",
    Icon = "radar",
})

BypassTab:Section({
    Title = "Game Bypass Features",
    Desc = "Advanced features to enhance gameplay",
})

-- Fishing Radar Section
BypassTab:Section({
    Title = "Fishing Radar",
    TextSize = 18,
    FontWeight = Enum.FontWeight.SemiBold,
})

BypassTab:Toggle({
    Title = "Fishing Radar",
    Flag = "FishingRadarToggle",
    Default = false,
    Callback = function(state)
        if state then
            StartFishingRadar()
        else
            StopFishingRadar()
        end
    end
})

BypassTab:Button({
    Title = "Toggle Radar",
    Icon = "radar",
    Callback = SafeToggleRadar
})

BypassTab:Space()

-- Diving Gear Section
BypassTab:Section({
    Title = "Diving Gear",
    TextSize = 18,
    FontWeight = Enum.FontWeight.SemiBold,
})

BypassTab:Toggle({
    Title = "Diving Gear",
    Flag = "DivingGearToggle",
    Default = false,
    Callback = function(state)
        if state then
            StartDivingGear()
        else
            StopDivingGear()
        end
    end
})

BypassTab:Button({
    Title = "Toggle Diving Gear",
    Icon = "diving",
    Callback = SafeToggleDivingGear
})

BypassTab:Space()

-- Auto Sell Section
BypassTab:Section({
    Title = "Auto Sell Fish",
    TextSize = 18,
    FontWeight = Enum.FontWeight.SemiBold,
})

BypassTab:Toggle({
    Title = "Auto Sell Fish",
    Desc = "Automatically sell fish when threshold is reached",
    Flag = "AutoSellToggle",
    Default = false,
    Callback = function(state)
        if state then
            StartAutoSell()
        else
            StopAutoSell()
        end
    end
})

BypassTab:Slider({
    Title = "Sell Threshold",
    Desc = "Minimum fish count to trigger auto sell",
    Flag = "AutoSellThreshold",
    Step = 1,
    Value = {
        Min = 1,
        Max = 50,
        Default = 3,
    },
    Callback = function(value)
        SetAutoSellThreshold(value)
    end
})

BypassTab:Button({
    Title = "Sell All Fish Now",
    Icon = "dollar-sign",
    Callback = ManualSellAllFish
})

BypassTab:Space()

-- Trick or Treat Section
BypassTab:Section({
    Title = "🎃 Trick or Treat",
    TextSize = 18,
    FontWeight = Enum.FontWeight.SemiBold,
})

BypassTab:Toggle({
    Title = "Auto Trick or Treat",
    Desc = "Automatically knocks on all Trick or Treat doors",
    Flag = "AutoTrickTreatToggle",
    Default = false,
    Callback = function(state)
        if state then
            StartAutoTrickTreat()
        else
            StopAutoTrickTreat()
        end
    end
})

BypassTab:Button({
    Title = "Knock All Doors Now",
    Icon = "door-open",
    Callback = ManualKnockAllDoors
})

BypassTab:Space()

-- Quick Actions Section
BypassTab:Section({
    Title = "Quick Actions",
    TextSize = 18,
    FontWeight = Enum.FontWeight.SemiBold,
})

BypassTab:Button({
    Title = "Enable All Bypass",
    Icon = "play",
    Color = Color3.fromHex("#30ff6a"),
    Justify = "Center",
    Callback = function()
        StartFishingRadar()
        StartDivingGear()
        StartAutoSell()
        StartAutoTrickTreat()
        Notify({Title = "Bypass", Content = "All bypass features enabled", Duration = 3})
    end
})

BypassTab:Button({
    Title = "Disable All Bypass",
    Icon = "square",
    Color = Color3.fromHex("#ff4830"),
    Justify = "Center",
    Callback = function()
        StopFishingRadar()
        StopDivingGear()
        StopAutoSell()
        StopAutoTrickTreat()
        Notify({Title = "Bypass", Content = "All bypass features disabled", Duration = 3})
    end
})

-- ========== PLAYER CONFIGURATION TAB ==========
local PlayerConfigTab = Window:Tab({
    Title = "Player Config",
    Icon = "settings",
})

-- Performance Section
PlayerConfigTab:Section({
    Title = "Performance",
    TextSize = 20,
    FontWeight = Enum.FontWeight.SemiBold,
})

PlayerConfigTab:Toggle({
    Title = "Ultra Anti Lag",
    Desc = "White texture mode for maximum performance",
    Flag = "AntiLagToggle",
    Default = false,
    Callback = function(state)
        if state then
            EnableAntiLag()
        else
            DisableAntiLag()
        end
    end
})

PlayerConfigTab:Space()

-- Position Section
PlayerConfigTab:Section({
    Title = "Position Management",
    TextSize = 20,
    FontWeight = Enum.FontWeight.SemiBold,
})

PlayerConfigTab:Button({
    Title = "Save Position",
    Icon = "bookmark",
    Callback = SaveCurrentPosition
})

PlayerConfigTab:Button({
    Title = "Load Position",
    Icon = "navigation",
    Callback = LoadSavedPosition
})

PlayerConfigTab:Toggle({
    Title = "Lock Position",
    Desc = "Prevent movement from saved position",
    Flag = "LockPositionToggle",
    Default = false,
    Callback = function(state)
        if state then
            StartLockPosition()
        else
            StopLockPosition()
        end
    end
})

PlayerConfigTab:Space()

-- Quick Actions
PlayerConfigTab:Section({
    Title = "Quick Actions",
    TextSize = 20,
    FontWeight = Enum.FontWeight.SemiBold,
})

PlayerConfigTab:Button({
    Title = "Max Performance",
    Icon = "zap",
    Color = Color3.fromHex("#30a2ff"),
    Justify = "Center",
    Callback = function()
        EnableAntiLag()
        Notify({Title = "Performance", Content = "Maximum performance enabled", Duration = 2})
    end
})

-- ========== TELEPORTATION TAB ==========
local TeleportTab = Window:Tab({
    Title = "Teleportation",
    Icon = "map-pin",
})

TeleportTab:Section({
    Title = "Location Teleport",
    Desc = "Quick teleport to fishing spots",
})

TeleportTab:Dropdown({
    Title = "Select Destination",
    Flag = "MapSelect",
    Values = {"Mount Hallow"},
    Value = "Mount Hallow",
    Callback = function(selected)
        currentSelectedMap = selected
    end
})

TeleportTab:Button({
    Title = "Teleport Now",
    Icon = "navigation",
    Callback = function()
        local pos = Vector3.new(1819, 12, 3043)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos)
            Notify({Title = "Teleport", Content = "Teleported to Mount Hallow", Duration = 2})
        end
    end
})

TeleportTab:Toggle({
    Title = "Show Coordinates",
    Desc = "Display current position coordinates",
    Flag = "ShowCoords",
    Default = false,
    Callback = function(v)
        if v then
            CreateCoordinateDisplay()
        else
            DestroyCoordinateDisplay()
        end
    end
})

-- ========== PLAYER MANAGEMENT TAB ==========
local PlayerTab = Window:Tab({
    Title = "Player Stats",
    Icon = "user",
})

PlayerTab:Section({
    Title = "Movement Configuration",
})

PlayerTab:Slider({
    Title = "Walk Speed",
    Desc = "Adjust player movement speed",
    Flag = "WalkSpeed",
    Step = 1,
    Value = {
        Min = 16,
        Max = 200,
        Default = 16,
    },
    Callback = function(val)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = val
        end
    end
})

PlayerTab:Slider({
    Title = "Jump Power",
    Desc = "Adjust player jump height",
    Flag = "JumpPower",
    Step = 1,
    Value = {
        Min = 50,
        Max = 350,
        Default = 50,
    },
    Callback = function(val)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.JumpPower = val
        end
    end
})

PlayerTab:Button({
    Title = "Reset Movement",
    Icon = "refresh-cw",
    Callback = function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = 16
            LocalPlayer.Character.Humanoid.JumpPower = 50
            Notify({Title = "Reset", Content = "Movement reset to default", Duration = 2})
        end
    end
})

-- ========== SETTINGS TAB ==========
local SettingsTab = Window:Tab({
    Title = "Settings",
    Icon = "settings-2",
})

SettingsTab:Button({
    Title = "Unload Hub",
    Icon = "power",
    Color = Color3.fromHex("#ff4830"),
    Justify = "Center",
    Callback = function()
        StopAutoFish()
        StopLockPosition()
        DisableAntiLag()
        StopFishingRadar()
        StopDivingGear()
        StopAutoSell()
        StopAutoTrickTreat()
        ToggleBlatantMode(false)
        DestroyCoordinateDisplay()
        Window:Destroy()
        Notify({Title = "Unload", Content = "Hub unloaded successfully", Duration = 2})
    end
})

SettingsTab:Button({
    Title = "Clean UI",
    Icon = "trash-2",
    Justify = "Center",
    Callback = function()
        for _, obj in ipairs(CoreGui:GetDescendants()) do
            pcall(function()
                if (obj:IsA("ImageLabel") or obj:IsA("ImageButton") or obj:IsA("TextLabel")) then
                    local name = (obj.Name or ""):lower()
                    local text = (obj.Text or ""):lower()
                    if string.find(name, "money") or string.find(text, "money") then
                        obj.Visible = false
                    end
                end
            end)
        end
        Notify({Title = "Clean", Content = "UI cleaned", Duration = 2})
    end
})

-- Initial Notification
Notify({
    Title = "Anggazyy Hub Ready", 
    Content = "WindUI System initialized successfully with UPDATED Continuous Blatant Fishing",
    Duration = 4
})

--//////////////////////////////////////////////////////////////////////////////////
-- WindUI System Initialization Complete
--//////////////////////////////////////////////////////////////////////////////////
