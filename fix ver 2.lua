-- Nhat Khanh Ultra Fix Lag | Dark Cyan Glass UI
-- Standalone Roblox client-side performance helper.
-- Based on performance techniques present in the supplied senav7 source.
-- It does NOT delete map objects, plots, pets, or eggs. Visual changes are reversible.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ENV = (getgenv and getgenv()) or _G

if ENV.__NKUltraFixLagCleanup then
    pcall(ENV.__NKUltraFixLagCleanup)
end

local alive = true
local connections = {}
local changed = {}       -- instance -> original property values
local effectChanged = {} -- instance -> original property values
local lowGraphicsOn = false
local effectsOff = false
local fpsCapOn = false
local oldQuality, oldSavedQuality
local oldLighting = {}
local oldTerrain = {}
local hiddenRewardLabels = {}
local hiddenDecorParts = {}
local rewardNumbersOn = true
local decorReductionOn = false
local oldFpsCap = 60
local fpsEstimate = 60
local lastTick = os.clock()
local frames = 0
-- Audio mute logic copied from the supplied Utra Fix Lag source.
local soundSaved = setmetatable({}, {__mode = "k"})
local muted = false
local soundAddedConnection

local function muteSound(sound)
    if not sound:IsA("Sound") then return end
    if soundSaved[sound] == nil then soundSaved[sound] = sound.Volume end
    pcall(function() sound.Volume = 0 end)
end

local function setMuted(on)
    muted = on
    if on then
        for _, obj in ipairs(game:GetDescendants()) do
            if obj:IsA("Sound") then muteSound(obj) end
        end
        if soundAddedConnection then soundAddedConnection:Disconnect() end
        soundAddedConnection = game.DescendantAdded:Connect(function(obj)
            if muted and obj:IsA("Sound") then
                task.defer(function()
                    if muted and obj.Parent then muteSound(obj) end
                end)
            end
        end)
    else
        if soundAddedConnection then
            soundAddedConnection:Disconnect()
            soundAddedConnection = nil
        end
        for sound, volume in pairs(soundSaved) do
            if sound and sound.Parent then
                pcall(function() sound.Volume = volume end)
            end
        end
        table.clear(soundSaved)
    end
end

local CYAN = Color3.fromRGB(0, 220, 255)
local CYAN_DARK = Color3.fromRGB(0, 105, 145)
local BG = Color3.fromRGB(5, 12, 22)
local PANEL = Color3.fromRGB(8, 24, 38)
local WHITE = Color3.fromRGB(225, 248, 255)
local MUTED = Color3.fromRGB(125, 170, 190)

local function addConnection(c)
    table.insert(connections, c)
    return c
end

local function saveProp(store, obj, prop)
    if not obj or not obj.Parent then return end
    store[obj] = store[obj] or {}
    if store[obj][prop] == nil then
        local ok, value = pcall(function() return obj[prop] end)
        if ok then store[obj][prop] = value end
    end
end

local function restoreStore(store)
    for obj, props in pairs(store) do
        if obj and obj.Parent then
            for prop, value in pairs(props) do
                pcall(function() obj[prop] = value end)
            end
        end
    end
    table.clear(store)
end

local function setFpsCap(value)
    local fn = (type(ENV.setfpscap) == "function" and ENV.setfpscap)
        or (type(ENV.set_fps_cap) == "function" and ENV.set_fps_cap)
        or (type(setfpscap) == "function" and setfpscap)
    if type(fn) == "function" then
        local ok = pcall(fn, value)
        return ok
    end
    return false
end

local function enableLowGraphics()
    if lowGraphicsOn then return end
    lowGraphicsOn = true

    pcall(function()
        oldQuality = settings().Rendering.QualityLevel
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    pcall(function()
        local ugs = UserSettings():GetService("UserGameSettings")
        oldSavedQuality = ugs.SavedQualityLevel
        ugs.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
    end)

    for _, prop in ipairs({"GlobalShadows", "FogEnd", "Brightness", "Technology"}) do
        saveProp(oldLighting, Lighting, prop)
    end
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1000000000
        Lighting.Brightness = 2
        Lighting.Technology = Enum.Technology.Compatibility
    end)

    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        for _, prop in ipairs({"WaterWaveSize", "WaterWaveSpeed", "WaterReflectance", "WaterTransparency", "Decoration"}) do
            saveProp(oldTerrain, terrain, prop)
        end
        pcall(function()
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 1
            terrain.Decoration = false
        end)
    end
end

local function disableLowGraphics()
    if not lowGraphicsOn then return end
    lowGraphicsOn = false
    restoreStore(oldLighting)
    restoreStore(oldTerrain)
    pcall(function()
        if oldQuality then settings().Rendering.QualityLevel = oldQuality end
    end)
    pcall(function()
        if oldSavedQuality then
            UserSettings():GetService("UserGameSettings").SavedQualityLevel = oldSavedQuality
        end
    end)
end

local function effectProperties(obj)
    if obj:IsA("ParticleEmitter") then
        saveProp(effectChanged, obj, "Enabled")
        saveProp(effectChanged, obj, "Rate")
        pcall(function() obj.Enabled = false; obj.Rate = 0 end)
    elseif obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke")
        or obj:IsA("Fire") or obj:IsA("Sparkles") or obj:IsA("Highlight")
        or obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight")
        or obj:IsA("BloomEffect") or obj:IsA("BlurEffect")
        or obj:IsA("ColorCorrectionEffect") or obj:IsA("SunRaysEffect")
        or obj:IsA("DepthOfFieldEffect") then
        saveProp(effectChanged, obj, "Enabled")
        pcall(function() obj.Enabled = false end)
    elseif obj:IsA("Atmosphere") then
        for _, prop in ipairs({"Density", "Haze", "Glare"}) do saveProp(effectChanged, obj, prop) end
        pcall(function() obj.Density = 0; obj.Haze = 0; obj.Glare = 0 end)
    elseif obj:IsA("BasePart") then
        saveProp(effectChanged, obj, "CastShadow")
        pcall(function() obj.CastShadow = false end)
    end
end

local function enableEffectsBoost()
    if effectsOff then return end
    effectsOff = true
    for _, root in ipairs({workspace, Lighting}) do
        for _, obj in ipairs(root:GetDescendants()) do
            effectProperties(obj)
        end
    end
    -- New effects are also suppressed while the toggle remains on.
    addConnection(workspace.DescendantAdded:Connect(function(obj)
        if effectsOff then task.defer(function()
            if alive and effectsOff and obj.Parent then pcall(effectProperties, obj) end
        end) end
    end))
    addConnection(Lighting.DescendantAdded:Connect(function(obj)
        if effectsOff then task.defer(function()
            if alive and effectsOff and obj.Parent then pcall(effectProperties, obj) end
        end) end
    end))
end

local function disableEffectsBoost()
    if not effectsOff then return end
    effectsOff = false
    restoreStore(effectChanged)
end

local function pingMs()
    local value = 0
    pcall(function()
        value = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return math.floor(tonumber(value) or 0)
end


local function isRewardNumberLabel(obj)
    if not obj:IsA("TextLabel") and not obj:IsA("TextButton") and not obj:IsA("TextBox") then return false end
    local txt = tostring(obj.Text or ""):lower():gsub("%s+", "")
    -- Match compact reward values without depending on a particular treadmill amount.
    txt = txt:gsub(",", ""):gsub("₫", ""):gsub("%$", "")
    return txt:match("^%+[%d%.]+[kmbtq]$") ~= nil
        or txt:match("^%+[%d%.]+$") ~= nil
end

local function scanRewardNumbers(obj)
    if not rewardNumbersOn or not obj or not obj.Parent then return end
    if isRewardNumberLabel(obj) then
        -- Hide the label and, when it belongs to a world-space floating tag,
        -- the BillboardGui/SurfaceGui container too. Other game UI stays untouched.
        saveProp(hiddenRewardLabels, obj, "Visible")
        pcall(function() obj.Visible = false end)
        local parent = obj.Parent
        while parent and parent ~= workspace and parent ~= playerGui do
            if parent:IsA("BillboardGui") or parent:IsA("SurfaceGui") then
                saveProp(hiddenRewardLabels, parent, parent:IsA("BillboardGui") and "Enabled" or "Enabled")
                pcall(function() parent.Enabled = false end)
                break
            end
            parent = parent.Parent
        end
    end
end

local function setRewardNumbersHidden(on)
    rewardNumbersOn = on
    if on then
        local roots = { workspace, playerGui }
        pcall(function() table.insert(roots, game:GetService("CoreGui")) end)
        pcall(function() if type(gethui) == "function" then table.insert(roots, gethui()) end end)
        for _, root in ipairs(roots) do
            pcall(function() for _, obj in ipairs(root:GetDescendants()) do scanRewardNumbers(obj) end end)
            addConnection(root.DescendantAdded:Connect(function(obj)
                if rewardNumbersOn then task.defer(function() if alive then scanRewardNumbers(obj) end end) end
            end))
        end
    else
        restoreStore(hiddenRewardLabels)
    end
end

local function isLikelyDecor(obj)
    if not obj:IsA("BasePart") then return false end
    local n = string.lower(obj.Name)
    -- Conservative name-based filter; never hides parts with gameplay-related names.
    local decor = n:find("fence", 1, true) or n:find("decoration", 1, true)
        or n:find("decor", 1, true) or n:find("bush", 1, true)
        or n:find("flower", 1, true) or n:find("foliage", 1, true)
    local gameplay = n:find("treadmill", 1, true) or n:find("egg", 1, true)
        or n:find("pet", 1, true) or n:find("plot", 1, true)
        or n:find("spawn", 1, true) or n:find("button", 1, true)
    return decor ~= nil and gameplay == nil
end

local function scanDecor(obj)
    if not decorReductionOn or not obj or not obj.Parent then return end
    if isLikelyDecor(obj) then
        saveProp(hiddenDecorParts, obj, "LocalTransparencyModifier")
        pcall(function() obj.LocalTransparencyModifier = 1 end)
    end
end

local function setDecorReduction(on)
    decorReductionOn = on
    if on then
        for _, obj in ipairs(workspace:GetDescendants()) do scanDecor(obj) end
        addConnection(workspace.DescendantAdded:Connect(function(obj)
            if decorReductionOn then task.defer(function() if alive then scanDecor(obj) end end) end
        end))
    else
        restoreStore(hiddenDecorParts)
    end
end

-- Siêu Fix Lag gốc được trích từ FixLag.lua.txt (v391 + toàn bộ helper phụ thuộc).
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = player
local genv = (type(getgenv) == "function" and getgenv()) or _G
local senaV4Config = {
    _fpsPlotsReady = false,
    _fpsTreadmillsReady = false,
    _fpsAreasReady = false,
    _fpsWorldReady = false,
    _fpsPetsReady = false,
    _fpsEggsReady = false,
    _fpsBoostApplying = nil,
}
local v391
local function v14()
    return Workspace:FindFirstChild("World") or Workspace:FindFirstChild("__OBJECTS")
end
local function v412(p83)
    if not p83:FindFirstAncestor("SenaVisualBack") and not p83:FindFirstAncestor("SenaVisualRemote") then
        local tool = p83:FindFirstAncestorWhichIsA("Tool")
        return tool ~= nil and tool:GetAttribute("NhatKhanhHub") ~= nil
    end
    return true
end

local u456 = false

local function v457(p84)
	if not p84 or not p84:IsA("Model") then
		return
	end

	local match = p84.Name:match("^(%d+)_")
	local v459 = match and tonumber(match)

	if not v459 or v459 == LocalPlayer.UserId then
		return
	end

	for _, descendant in ipairs(p84:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = 1
		elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
			descendant.Enabled = false
		elseif descendant:IsA("BillboardGui") or descendant:IsA("SurfaceGui") then
			descendant.Enabled = false
		end
	end
end
local function v462()
	if senaV4Config._fpsEggsReady then
		return true
	end

	local u463 = false
	local ok, result = pcall(function()
		local v466 = require(game:GetService("ReplicatedStorage").Shared.Eggs.PlacedEggRenderer).GetRenderFolder()

		if not v466 then
			return
		end

		local children = v466:GetChildren()

		for _, child in ipairs(children) do
			v457(child)
		end

		v466.ChildAdded:Connect(function(child)
			task.defer(v457, child)
		end)
		u463 = true
	end)

	if not ok then
		warn("[FPSBoost] Gagal hide egg pemain lain:", result)

		return false
	end

	return u463
end
local function v470(p85)
	if not p85 then
		return
	end

	pcall(function()
		p85.Parent = nil
	end)
end
local function v471()
	if senaV4Config._fpsPetsReady then
		return true
	end

	local IsOn
	local ok, result = pcall(function()
		local Shared = game:GetService("ReplicatedStorage").Shared
		local Preferences = Shared:FindFirstChild("Preferences")

		if Preferences then
			local module = require(Preferences)

			module.Set("HideOtherPets", true)
			IsOn = module.IsOn
		else
			local SettingsCmds = require(Shared.SettingsCmds)

			SettingsCmds.Write("HideOtherPets", true)
			IsOn = SettingsCmds.Allows
		end
	end)
	local v479 = false

	if ok and IsOn then
		local ok2, result2 = pcall(IsOn, "HideOtherPets")

		v479 = ok2 and result2 == true
	end

	if ok then
		if v479 then
			local u482 = false
			local ok2, result2 = pcall(function()
				local ClientRenderedAssets = workspace:FindFirstChild("ClientRenderedAssets") or workspace:WaitForChild("ClientRenderedAssets", 10)

				if not ClientRenderedAssets then
					return
				end

				local children = ClientRenderedAssets:GetChildren()

				for _, child in ipairs(children) do
					v470(child)
				end

				ClientRenderedAssets.ChildAdded:Connect(function(child)
					task.defer(v470, child)
				end)
				u482 = true
			end)

			if not ok2 then
				warn("[FPSBoost] Gagal hide pet (manual):", result2)

				return false
			end

			return u482
		end
	end

	warn("[FPSBoost] Gagal set HideOtherPets bawaan game:", result or "setting belum aktif")

	return false
end
local function v489()
	if type(genv.__SenaV4SetCapFps) == "function" then
		pcall(genv.__SenaV4SetCapFps, 240)
	end

	pcall(function()
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
	end)

	local function v490()
		UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
	end

	pcall(v490)
	pcall(function()
		require(game:GetService("ReplicatedStorage").Client.LightingsController):SetModifier("FPSBoost", function(p86)
			local v491 = table.clone(p86)

			v491.Bloom = nil
			v491.ColorCorrection = nil
			v491.SunRays = nil
			v491.DepthOfField = nil
			v491.Blur = nil
			v491.Clouds = nil
			v491.Atmosphere = nil
			v491.ShadowSoftness = 1

			return v491
		end, 100, 0)
	end)
	pcall(function()
		local Lighting = game:GetService("Lighting")

		Lighting.GlobalShadows = false
		Lighting.Technology = Enum.Technology.Compatibility
		Lighting.FogEnd = 9e9
		Lighting.Brightness = 2
	end)
	pcall(function()
		local Terrain = workspace:FindFirstChildOfClass("Terrain")

		if Terrain then
			Terrain.WaterWaveSize = 0
			Terrain.WaterWaveSpeed = 0
			Terrain.WaterReflectance = 0
			Terrain.WaterTransparency = 1
			Terrain.Decoration = false
		end
	end)
	pcall(function()
		local __DEBRIS = workspace:FindFirstChild("__DEBRIS")

		if __DEBRIS then
			for _, child in ipairs(__DEBRIS:GetChildren()) do
				if child.Name == "PlayerTrap" then
					pcall(function()
						child:Destroy()
					end)
				end
			end
		end
	end)
end

local color3 = Color3.fromRGB(120, 120, 120)

local function v498(p87)
	if not p87 or not p87:IsA("BasePart") then
		return
	end

	p87.Material = Enum.Material.SmoothPlastic
	p87.Color = color3
	p87.CastShadow = false
end
local function v499(p88)
	if p88:IsA("ParticleEmitter") then
		p88.Enabled = false
		p88.Rate = 0
		pcall(function()
			p88:Clear()
		end)
	elseif p88:IsA("Trail") or p88:IsA("Beam") or p88:IsA("Smoke") or p88:IsA("Fire") or p88:IsA("Sparkles") or p88:IsA("PostEffect") or p88:IsA("Light") or p88:IsA("Highlight") or p88:IsA("Clouds") then
		p88.Enabled = false
	elseif p88:IsA("Atmosphere") then
		p88.Density = 0
		p88.Haze = 0
		p88.Glare = 0
	elseif p88:IsA("Explosion") then
		pcall(function()
			p88.Visible = false
		end)
	end
end
local function v500()
	if senaV4Config._fpsWorldReady then
		return true
	end

	local u501 = false
	local t20 = {}
	local ok, result = pcall(function()
		local function v505(p89)
			if v412(p89) then
				return
			end

			v498(p89)
			v499(p89)
		end

		local t21 = {
			workspace,
			game:GetService("Lighting")
		}

		for _, v in ipairs(t21) do
			table.insert(t20, v.DescendantAdded:Connect(function(descendant)
				task.defer(v505, descendant)
			end))
		end

		local t22 = {}

		for _, v in ipairs(t21) do
			for _, child in ipairs(v:GetChildren()) do
				table.insert(t22, child)
			end
		end

		local n11 = 0

		while #t22 > 0 do
			local v515 = table.remove(t22)

			v505(v515)

			for _, child in ipairs(v515:GetChildren()) do
				table.insert(t22, child)
			end

			n11 += 1

			if n11 >= 250 and #t22 > 0 then
				n11 = 0
				RunService.Heartbeat:Wait()
			end
		end

		u501 = true
	end)

	if ok then
		return u501
	end

	for _, v in ipairs(t20) do
		v:Disconnect()
	end

	warn("[FPSBoost] Gagal flatten material workspace:", result)

	return false
end
local function v520()
	if senaV4Config._fpsAreasReady then
		return true
	end

	local v521 = v14()
	local Areas = v521 and v521:FindFirstChild("Areas")
	local GuardAreas = Areas and Areas:FindFirstChild("GuardAreas")
	local Build = v521 and v521:FindFirstChild("Build")

	if not GuardAreas or not Build then
		return false
	end

	for _, child in ipairs(GuardAreas:GetChildren()) do
		local RequiredSpeedSign = child:FindFirstChild("RequiredSpeedSign")

		if RequiredSpeedSign then
			pcall(function()
				RequiredSpeedSign:Destroy()
			end)
		end
	end

	local MainMap = Build:FindFirstChild("MainMap")
	local Bases = MainMap and MainMap:FindFirstChild("Bases")

	local function v530(p90)
		if Bases and p90:IsDescendantOf(Bases) then
			return p90.Size.Y <= 5 and not string.find(string.upper(p90.Name), "WALL", 1, true)
		end

		local Parent = p90

		while true do
			if not Parent or Parent == Build then
				return false
			end

			if not string.find(string.upper(Parent.Name), "BOTTOM", 1, true) then
				Parent = Parent.Parent

				continue
			end

			break
		end

		return true
	end

	local t23 = {
		"ENCHANTED",
		"FUSEBIOME",
		"WISP",
		"BUTTERFLY",
		"MARKERS",
		"PORTAL",
		"TRIGGER"
	}

	local function v533(p91)
		if p91:FindFirstChildOfClass("TouchTransmitter") or p91:FindFirstChildWhichIsA("ProximityPrompt", true) then
			return true
		end

		local Parent = p91

		while true do
			if not Parent then
				return false
			end

			if Parent == Build then
				return false
			end

			local v535 = string.upper(Parent.Name)

			for _, v in ipairs(t23) do
				if string.find(v535, v, 1, true) then
					return true
				end
			end

			Parent = Parent.Parent
		end
	end
	local function v538(p92)
		if not p92:IsA("BasePart") then
			return
		end

		if v533(p92) then
			return
		end

		if v530(p92) then
			v498(p92)
		else
			pcall(function()
				p92:Destroy()
			end)
		end
	end

	local connection = Build.DescendantAdded:Connect(function(descendant)
		task.defer(v538, descendant)
	end)
	local n12 = 0
	local fpsAreaDeleted = 0

	for _, descendant in ipairs(Build:GetDescendants()) do
		local v544 = descendant.Parent ~= nil

		v538(descendant)

		if v544 and descendant.Parent == nil then
			fpsAreaDeleted += 1
		end

		n12 += 1

		if n12 >= 250 then
			n12 = 0
			RunService.Heartbeat:Wait()
		end
	end

	senaV4Config._fpsAreaListener = connection
	senaV4Config._fpsAreaDeleted = fpsAreaDeleted
	senaV4Config._fpsAreasReady = true

	return true
end
local function v545()
	if senaV4Config._fpsPlotsReady then
		return true
	end

	local u546 = false
	local ok, result = pcall(function()
		local PlotState2 = require(game:GetService("ReplicatedStorage").Client.PlotState)

		if PlotState2.GetMySlot() == nil then
			warn("[FPSBoost] Slot plot kita belum ke-resolve, skip delete plot dulu (biar aman).")

			return
		end

		local function v550(p93)
			local v551 = PlotState2.GetMySlot()

			return v551 ~= nil and p93.Name == tostring(v551)
		end

		local Plots = PlotState2.GetPlotsFolder() or workspace:WaitForChild("Plots", 10)

		if not Plots then
			warn("[FPSBoost] workspace.Plots gak ketemu sama sekali.")

			return
		end

		local children = Plots:GetChildren()
		local n13 = 0

		for _, child in ipairs(children) do
			if not v550(child) and pcall(function()
				child:Destroy()
			end) then
				n13 += 1
			end
		end

		Plots.ChildAdded:Connect(function(child)
			task.defer(function()
				if child.Parent then
					if not v550(child) then
						pcall(function()
							child:Destroy()
						end)
					end
				end
			end)
		end)
		u546 = true
	end)

	if ok then
		return u546
	end

	warn("[FPSBoost] Gagal delete plot pemain lain:", result)

	return false
end
local function v557()
	if senaV4Config._fpsTreadmillsReady then
		return true
	end

	local u558 = false
	local ok, result = pcall(function()
		local ReplicatedStorage2 = game:GetService("ReplicatedStorage")
		local PlotState2 = require(ReplicatedStorage2.Client.PlotState)
		local v563
		local Modules = ReplicatedStorage2.Client:FindFirstChild("Modules") or ReplicatedStorage2.Client:WaitForChild("Modules", 10)
		local RuntimeInstanceRegistry = Modules and (Modules:FindFirstChild("RuntimeInstanceRegistry") or Modules:WaitForChild("RuntimeInstanceRegistry", 10))

		if RuntimeInstanceRegistry then
			local ok, result = pcall(require, RuntimeInstanceRegistry)

			if ok then
				v563 = result
			end
		end

		local __ClientTreadmillRenders = workspace:FindFirstChild("__ClientTreadmillRenders") or workspace:WaitForChild("__ClientTreadmillRenders", 10)

		if not __ClientTreadmillRenders then
			return
		end

		local function v569()
			local v570 = PlotState2.GetMySlot()

			if v570 == nil then
				return nil
			end

			local v571 = __ClientTreadmillRenders:FindFirstChild("TreadmillRender_" .. tostring(v570))

			if v571 then
				return v571
			end

			local Peek = v563 and (v563.Peek or v563.Get)

			if not Peek then
				return nil
			end

			local ok, result = pcall(Peek, "TreadmillPlotRender", tostring(v570))

			if ok then
				return result
			end

			return nil
		end
		local function v575(p94)
			local v576 = v569()

			if v576 and p94 == v576 then
				return true
			end

			local ok, result = pcall(function()
				return p94:GetPivot().Position
			end)

			if not ok then
				return true
			end

			local ok2, result2 = pcall(PlotState2.IsWorldPositionWithinLocalPlotBounds, result)
			local v581 = ok2 and result2

			return v581
		end

		local children = __ClientTreadmillRenders:GetChildren()
		local n14 = 0

		for _, child in ipairs(children) do
			if child:IsA("Model") and not v575(child) and pcall(function()
				child:Destroy()
			end) then
				n14 += 1
			end
		end

		__ClientTreadmillRenders.ChildAdded:Connect(function(child)
			task.defer(function()
				if child.Parent and child:IsA("Model") and not v575(child) then
					pcall(function()
						child:Destroy()
					end)
				end
			end)
		end)
		u558 = true
	end)

	if ok then
		return u558
	end

	warn("[FPSBoost] Gagal delete treadmill pemain lain:", result)

	return false
end

v391 = function()
	if u456 or senaV4Config._fpsBoostApplying then
		return
	end

	senaV4Config._fpsBoostApplying = true

	local ok, result = pcall(function()
		v489()
		senaV4Config._fpsPlotsReady = v545() == true
		senaV4Config._fpsTreadmillsReady = v557() == true
		senaV4Config._fpsAreasReady = v520() == true
		senaV4Config._fpsWorldReady = v500() == true
		senaV4Config._fpsPetsReady = v471() == true
		senaV4Config._fpsEggsReady = v462() == true
		u456 = senaV4Config._fpsEggsReady and senaV4Config._fpsPetsReady and senaV4Config._fpsWorldReady and senaV4Config._fpsPlotsReady and senaV4Config._fpsTreadmillsReady and senaV4Config._fpsAreasReady
	end)

	senaV4Config._fpsBoostApplying = nil

	if not ok then
		warn("[FPSBoost] Gagal menerapkan FPS Boost:", result)
	end
end

-- Siêu Fix Lag now calls the original v391() orchestration and its full helper chain.
-- Source gốc thứ 2: v391() gọi v489() cùng các helper phụ thuộc của hub.
local function sourceFPSBoost()
    if type(v391) ~= "function" then
        error("Không khởi tạo được chuỗi FPS Boost gốc v391")
    end
    v391()
    return senaV4Config._fpsEggsReady and senaV4Config._fpsPetsReady
        and senaV4Config._fpsWorldReady and senaV4Config._fpsPlotsReady
        and senaV4Config._fpsTreadmillsReady and senaV4Config._fpsAreasReady
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "NhatKhanhUltraFixLag"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 12)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or CYAN
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.Parent = parent
    return s
end

local function label(parent, text, size, pos, font, color)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.Size = size
    l.Position = pos
    l.Font = font or Enum.Font.Gotham
    l.TextColor3 = color or WHITE
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local shadow = Instance.new("Frame")
shadow.Name = "DepthShadow"
shadow.Size = UDim2.fromOffset(294, 408)
shadow.Position = UDim2.new(0.5, -144, 0.5, -204)
shadow.BackgroundColor3 = CYAN_DARK
shadow.BackgroundTransparency = 0.68
shadow.BorderSizePixel = 0
shadow.Parent = gui
corner(shadow, 18)

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(286, 400)
main.Position = UDim2.new(0.5, -150, 0.5, -200)
main.BackgroundColor3 = BG
main.BackgroundTransparency = 0.12
main.BorderSizePixel = 0
main.Parent = gui
corner(main, 16)
stroke(main, CYAN, 1.25, 0.18)

local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 34, 52)),
    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(5, 15, 27)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 38, 53)),
})
grad.Rotation = 35
grad.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1, -16, 0, 40)
header.Position = UDim2.fromOffset(8, 7)
header.BackgroundColor3 = PANEL
header.BackgroundTransparency = 0.18
header.BorderSizePixel = 0
header.Parent = main
corner(header, 11)
stroke(header, CYAN_DARK, 1, 0.15)

local title = label(header, "NK  /  TỐI ƯU FPS", UDim2.new(1, -72, 0, 20), UDim2.fromOffset(12, 5), Enum.Font.GothamBold, CYAN)
title.TextSize = 13
local subtitle = label(header, "GIẢM LAG  •  FPS / PING", UDim2.new(1, -72, 0, 13), UDim2.fromOffset(12, 23), Enum.Font.Gotham, MUTED)
subtitle.TextSize = 8

local hideButton = Instance.new("TextButton")
hideButton.Size = UDim2.fromOffset(28, 26)
hideButton.Position = UDim2.new(1, -34, 0, 7)
hideButton.Text = "—"
hideButton.Font = Enum.Font.GothamBold
hideButton.TextSize = 18
hideButton.TextColor3 = CYAN
hideButton.BackgroundColor3 = Color3.fromRGB(0, 48, 67)
hideButton.BackgroundTransparency = 0.12
hideButton.BorderSizePixel = 0
hideButton.Parent = header
corner(hideButton, 8)

local status = label(main, "TRẠNG THÁI  •  SẴN SÀNG", UDim2.new(1, -24, 0, 16), UDim2.fromOffset(13, 54), Enum.Font.GothamBold, MUTED)
status.TextSize = 9

local statsCard = Instance.new("Frame")
statsCard.Size = UDim2.new(1, -24, 0, 42)
statsCard.Position = UDim2.fromOffset(12, 73)
statsCard.BackgroundColor3 = PANEL
statsCard.BackgroundTransparency = 0.22
statsCard.BorderSizePixel = 0
statsCard.Parent = main
corner(statsCard, 10)
stroke(statsCard, CYAN_DARK, 1, 0.3)

local fpsLabel = label(statsCard, "FPS  60", UDim2.new(0.5, -10, 1, 0), UDim2.fromOffset(10, 0), Enum.Font.GothamBold, CYAN)
fpsLabel.TextSize = 16
local pingLabel = label(statsCard, "PING  -- ms", UDim2.new(0.5, -10, 1, 0), UDim2.new(0.5, 0, 0, 0), Enum.Font.GothamBold, WHITE)
pingLabel.TextSize = 14

local function makeToggle(text, y, initial, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -24, 0, 32)
    row.Position = UDim2.fromOffset(12, y)
    row.BackgroundColor3 = PANEL
    row.BackgroundTransparency = 0.24
    row.BorderSizePixel = 0
    row.Parent = main
    corner(row, 9)
    stroke(row, CYAN_DARK, 1, 0.5)

    local t = label(row, text, UDim2.new(1, -68, 1, 0), UDim2.fromOffset(10, 0), Enum.Font.GothamSemibold, WHITE)
    t.TextSize = 11

    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(48, 22)
    button.Position = UDim2.new(1, -56, 0.5, -11)
    button.BorderSizePixel = 0
    button.TextSize = 9
    button.Font = Enum.Font.GothamBold
    button.Parent = row
    corner(button, 8)
    local enabled = initial == true

    local function draw()
        button.Text = enabled and "BẬT" or "TẮT"
        button.BackgroundColor3 = enabled and CYAN_DARK or Color3.fromRGB(30, 42, 53)
        button.TextColor3 = enabled and Color3.fromRGB(235, 255, 255) or MUTED
    end
    button.MouseButton1Click:Connect(function()
        enabled = not enabled
        draw()
        local ok = pcall(callback, enabled)
        if not ok then status.Text = "TRẠNG THÁI  •  MỘT SỐ TÙY CHỌN KHÔNG HỖ TRỢ" end
    end)
    draw()
    return function(value)
        enabled = value
        draw()
        pcall(callback, enabled)
    end
end

local setLow = makeToggle("Giảm chất lượng đồ họa", 122, false, function(on)
    if on then enableLowGraphics() else disableLowGraphics() end
    status.Text = on and "TRẠNG THÁI  •  ĐÃ GIẢM ĐỒ HỌA" or "TRẠNG THÁI  •  ĐỒ HỌA MẶC ĐỊNH"
end)

local setEffects = makeToggle("Tắt hiệu ứng để giảm lag", 160, false, function(on)
    if on then enableEffectsBoost() else disableEffectsBoost() end
    status.Text = on and "TRẠNG THÁI  •  ĐÃ GIẢM HIỆU ỨNG" or "TRẠNG THÁI  •  ĐÃ KHÔI PHỤC HIỆU ỨNG"
end)

local setSuper = makeToggle("SIÊU FIX LAG", 350, false, function(on)
    if on then
        status.Text = "TRẠNG THÁI  •  ĐANG CHẠY SIÊU FIX LAG..."
        task.spawn(function()
            local ok, result = pcall(function()
                return sourceFPSBoost()
            end)
            if not alive then return end
            if ok then
                status.Text = result
                    and "TRẠNG THÁI  •  SIÊU FIX LAG ĐÃ CHẠY"
                    or "TRẠNG THÁI  •  ĐÃ CHẠY, MỘT SỐ PHẦN GAME KHÔNG HỖ TRỢ"
            else
                status.Text = "TRẠNG THÁI  •  SIÊU FIX LAG LỖI: " .. tostring(result):sub(1, 70)
            end
        end)
    else
        status.Text = "TRẠNG THÁI  •  SIÊU FIX LAG ĐÃ TẮT NÚT; CÁC THAY ĐỔI GỐC CÓ THỂ KHÔNG HOÀN TÁC"
    end
end)

local setMute = makeToggle("Tắt hết âm thanh", 198, false, function(on)
    setMuted(on)
    status.Text = on and "TRẠNG THÁI  •  ĐÃ TẮT HẾT ÂM THANH" or "TRẠNG THÁI  •  ĐÃ KHÔI PHỤC ÂM THANH"
end)

local setCap = makeToggle("Mở giới hạn FPS (nếu hỗ trợ)", 236, false, function(on)
    if on then
        fpsCapOn = setFpsCap(240)
        status.Text = fpsCapOn and "TRẠNG THÁI  •  ĐÃ YÊU CẦU FPS 240" or "TRẠNG THÁI  •  DELTA KHÔNG HỖ TRỢ GIỚI HẠN FPS"
    else
        setFpsCap(oldFpsCap)
        fpsCapOn = false
        status.Text = "TRẠNG THÁI  •  ĐÃ YÊU CẦU ĐẶT LẠI FPS"
    end
end)

local setRewardNumbers = makeToggle("Ẩn số thưởng nổi", 274, true, function(on)
    setRewardNumbersHidden(on)
    status.Text = on and "TRẠNG THÁI  •  ĐANG ẨN SỐ THƯỞNG" or "TRẠNG THÁI  •  HIỆN SỐ THƯỞNG"
end)

local setDecor = makeToggle("Ẩn hàng rào / đồ trang trí", 312, false, function(on)
    setDecorReduction(on)
    status.Text = on and "TRẠNG THÁI  •  ĐÃ ẨN ĐỒ TRANG TRÍ" or "TRẠNG THÁI  •  ĐÃ HIỆN LẠI ĐỒ TRANG TRÍ"
end)

setRewardNumbersHidden(true) -- Mặc định ẩn số thưởng nổi ngay khi chạy script.

local footer = label(main, "KÉO THANH ĐẦU ĐỂ DI CHUYỂN  •  — ĐỂ THU NHỎ", UDim2.new(1, -24, 0, 12), UDim2.fromOffset(12, 384), Enum.Font.Gotham, MUTED)
footer.TextSize = 8
footer.TextXAlignment = Enum.TextXAlignment.Center

-- Floating restore icon shown when the full GUI is hidden.
local reopen = Instance.new("TextButton")
reopen.Name = "ReopenButton"
reopen.Size = UDim2.fromOffset(88, 42)
reopen.Position = UDim2.new(0, 18, 0.45, 0)
reopen.BackgroundColor3 = Color3.fromRGB(3, 23, 38)
reopen.BackgroundTransparency = 0.08
reopen.BorderSizePixel = 0
reopen.Text = ""
reopen.Font = Enum.Font.GothamBlack
reopen.TextSize = 13
reopen.TextColor3 = CYAN
reopen.Visible = false
reopen.Parent = gui
corner(reopen, 16)
stroke(reopen, CYAN, 1.5, 0.05)

-- The floating NK icon is a compact live FPS/Ping widget.
local miniFps = Instance.new("TextLabel")
miniFps.Name = "MiniFPS"
miniFps.BackgroundTransparency = 1
miniFps.Position = UDim2.fromOffset(5, 3)
miniFps.Size = UDim2.new(1, -10, 0, 17)
miniFps.Font = Enum.Font.GothamBold
miniFps.TextSize = 11
miniFps.TextColor3 = CYAN
miniFps.Text = "FPS --  ·  MỞ"
miniFps.Parent = reopen

local miniPing = Instance.new("TextLabel")
miniPing.Name = "MiniPing"
miniPing.BackgroundTransparency = 1
miniPing.Position = UDim2.fromOffset(5, 21)
miniPing.Size = UDim2.new(1, -10, 0, 15)
miniPing.Font = Enum.Font.GothamSemibold
miniPing.TextSize = 8
miniPing.TextColor3 = WHITE
miniPing.Text = "PING -- ms"
miniPing.Parent = reopen

local function setVisible(visible)
    main.Visible = visible
    shadow.Visible = visible
    reopen.Visible = not visible
end
hideButton.MouseButton1Click:Connect(function() setVisible(false) end)

-- Kéo widget mini FPS/Ping bằng ngón tay; chạm nhanh để mở menu.
do
    local miniDragging = false
    local miniMoved = false
    local miniStart, miniPos
    reopen.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            miniDragging = true
            miniMoved = false
            miniStart = input.Position
            miniPos = reopen.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if miniDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - miniStart
            if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then miniMoved = true end
            reopen.Position = UDim2.new(miniPos.X.Scale, miniPos.X.Offset + delta.X, miniPos.Y.Scale, miniPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if miniDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
            miniDragging = false
            if not miniMoved then setVisible(true) end
        end
    end)
end

-- Drag window on touch or mouse.
do
    local dragging = false
    local dragInput, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            shadow.Position = UDim2.new(main.Position.X.Scale, main.Position.X.Offset + 6, main.Position.Y.Scale, main.Position.Y.Offset + 8)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

addConnection(RunService.Heartbeat:Connect(function()
    frames += 1
    local now = os.clock()
    if now - lastTick >= 0.5 then
        fpsEstimate = math.floor((frames / (now - lastTick)) + 0.5)
        frames = 0
        lastTick = now
        if gui.Parent then
            local ping = pingMs()
            fpsLabel.Text = "FPS  " .. tostring(fpsEstimate)
            pingLabel.Text = "PING  " .. tostring(ping) .. " ms"
            miniFps.Text = "FPS " .. tostring(fpsEstimate)
            miniPing.Text = tostring(ping) .. " ms"
        end
    end
end))

ENV.__NKUltraFixLagCleanup = function()
    alive = false
    pcall(disableEffectsBoost)
    pcall(disableLowGraphics)
    pcall(function() setRewardNumbersHidden(false) end)
    pcall(function() setDecorReduction(false) end)
    if fpsCapOn then pcall(setFpsCap, oldFpsCap) end
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    if gui then pcall(function() gui:Destroy() end) end
    ENV.__NKUltraFixLagCleanup = nil
end

print("[Nhat Khanh Ultra Fix Lag] Loaded")
