-- GHOST HUB | Bootstrap + Re-Execute after teleport
-- Executor cần hỗ trợ loadstring và queue_on_teleport/queueonteleport.

local HUB_SOURCE = [==========[
--[[
    GHOST HUB | Steal An Egg
    Chilli V4 = Auto Sell Pet
    Do Hoa     = Auto Sell Pet
    FPS        = Auto Sell Egg
    Anti AFK   = Auto Sell Egg

    All auto functions enabled
    Auto cycle: 0.5 second
    No close button
]]

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

-- PERMANENT SILENCE: mute existing and newly-created game sounds.
-- Sound volumes are forced to 0 for the whole session and are never restored.
local function muteSound(sound)
    if sound:IsA("Sound") then
        pcall(function() sound.Volume = 0 end)
    end
end

local function beginSilentSell()
    -- Kept as a no-op-compatible call for the existing sell logic.
    for _, item in ipairs(game:GetDescendants()) do
        muteSound(item)
    end
end

-- Mute sounds already present and every sound added later.
for _, item in ipairs(game:GetDescendants()) do
    muteSound(item)
end

game.DescendantAdded:Connect(function(item)
    muteSound(item)
end)

-- Some game scripts may raise a Sound's volume again; force it back to 0.
task.spawn(function()
    while true do
        for _, item in ipairs(game:GetDescendants()) do
            muteSound(item)
        end
        task.wait(0.5)
    end
end)

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

local autoPet = true
local autoEgg = true
local running = true
local busy = false

local STATUS_TEXT = "Chờ 30 giây loading...."

--==================================================
-- MODULES
--==================================================

local function requirePath(root, path)
    local node = root

    for part in string.gmatch(path, "[^%.]+") do
        node = node and node:FindFirstChild(part)
    end

    if not node then
        return nil
    end

    local ok, result = pcall(require, node)

    if ok then
        return result
    end

    return nil
end

local Save = requirePath(RS, "Shared.Save")
    or requirePath(RS, "Client.Save")

local AssetItems = requirePath(
    RS,
    "Shared.Util.AssetItems"
)

local EggRecords = requirePath(
    RS,
    "Shared.Util.EggRecords"
)

local Remotes = requirePath(RS, "Shared.Remotes")

local function getSave()
    if not Save then
        return nil
    end

    local getter = Save.Get or Save.Peek

    if not getter then
        return nil
    end

    local ok, result = pcall(getter)

    if ok and type(result) == "table" then
        return result
    end

    return nil
end

local function decodePet(raw)
    if type(raw) == "table" and raw.Category then
        return raw
    end

    if AssetItems and AssetItems.Decode then
        local ok, result = pcall(
            AssetItems.Decode,
            raw
        )

        if ok and type(result) == "table" then
            return result
        end
    end

    return nil
end

local function decodeEgg(raw)
    if type(raw) == "table"
        and (raw.AssetCategory or raw.Category) then
        return raw
    end

    if EggRecords and EggRecords.Decode then
        local ok, result = pcall(
            EggRecords.Decode,
            raw
        )

        if ok and type(result) == "table" then
            return result
        end
    end

    return nil
end

--==================================================
-- SELL LOGIC
--==================================================

local function canSell()
    local ok, guard = pcall(function()
        return require(RS.Client.ToolGameplayGuard)
    end)

    if ok and guard and guard.IsLocalInsideArena then
        local success, inside = pcall(
            guard.IsLocalInsideArena
        )

        if success and inside then
            return false
        end
    end

    local character = LP.Character

    if character then
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Tool")
                and item:GetAttribute("ItemType") == "AssetEgg" then
                return false
            end
        end
    end

    return true
end

local function getSellRemote()
    local remote = Remotes
        and Remotes.PetSatchel
        and Remotes.PetSatchel.SellSelection

    if remote then
        return remote
    end

    local packages = RS:FindFirstChild("Packages")
    local networking = packages
        and packages:FindFirstChild("Networking")

    return networking
        and networking:FindFirstChild(
            "RE/PetSatchel/SellSelection"
        )
end

local function sellSelection(petIds, eggIds)
    if not canSell() then
        return false
    end

    if #petIds == 0 and #eggIds == 0 then
        return false
    end

    local remote = getSellRemote()
    if not remote then
        return false
    end

    beginSilentSell()
    local ok = pcall(function()
        remote:FireServer({
            Assets = petIds,
            Eggs = eggIds
        })
    end)

    return ok
end

local function collectPets()
    local save = getSave()

    if not save then
        return {}
    end

    local inventory = save.Inventory or {}
    local equipped = {}

    for _, uid in ipairs(save.EquippedAssets or {}) do
        equipped[uid] = true
    end

    local ids = {}

    for uid, raw in pairs(inventory) do
        local pet = decodePet(raw)

        if pet
            and pet.Category
            and not equipped[uid]
            and pet.IsFavorite ~= true
            and pet.Favorite ~= true
            and pet.Locked ~= true
            and not pet.InFuse then

            table.insert(ids, uid)
        end
    end

    return ids
end

local function collectEggs()
    local save = getSave()

    if not save then
        return {}
    end

    local inventory = save.EggInventory or {}
    local ids = {}

    for uid, raw in pairs(inventory) do
        local egg = decodeEgg(raw)

        if egg
            and (egg.AssetCategory or egg.Category)
            and egg.Placement == nil
            and egg.IsFavorite ~= true
            and egg.Favorite ~= true
            and egg.Locked ~= true
            and not (
                type(egg.Mutations) == "table"
                and next(egg.Mutations) ~= nil
            ) then

            table.insert(ids, uid)
        end
    end

    return ids
end

local function sellPets()
    return sellSelection(collectPets(), {})
end

local function sellEggs()
    return sellSelection({}, collectEggs())
end

--==================================================
-- UNFAVORITE ALL PETS
-- Reused from the supplied NhatKhanhHub source:
-- Remotes.PetSatchel.WriteFavourite:FireServer(uid, false)
--==================================================

local function unfavoriteAll()
    local save = getSave()

    if not save or type(save.Inventory) ~= "table" then
        return 0
    end

    local count = 0

    for uid, raw in pairs(save.Inventory) do
        local pet = decodePet(raw)

        if type(pet) == "table" and pet.IsFavorite == true then
            local remote = Remotes
                and Remotes.PetSatchel
                and Remotes.PetSatchel.WriteFavourite

            if remote then
                local ok = pcall(function()
                    remote:FireServer(uid, false)
                end)

                if ok then
                    count += 1

                    if count % 10 == 0 then
                        task.wait(0.05)
                    end
                end
            end
        end
    end

    return count
end

--==================================================
-- GUI
--==================================================

local old = PlayerGui:FindFirstChild("GhostHub")

if old then
    old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "GhostHub"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
-- Ẩn hoàn toàn giao diện; giữ ScreenGui được parent để các vòng lặp nền vẫn chạy.
gui.Enabled = false
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(235, 230)
main.Position = UDim2.new(0.5, -117, 0.35, 0)
main.BackgroundColor3 = Color3.fromRGB(9, 8, 17)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 13)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(145, 65, 220)
mainStroke.Thickness = 2
mainStroke.Parent = main

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -42, 0, 37)
title.Position = UDim2.fromOffset(10, 2)
title.BackgroundTransparency = 1
title.Text = "GHOST HUB"
title.TextColor3 = Color3.fromRGB(220, 190, 255)
title.Font = Enum.Font.GothamBlack
title.TextSize = 18
title.Parent = main

local bat = Instance.new("TextLabel")
bat.Size = UDim2.fromOffset(30, 30)
bat.Position = UDim2.new(1, -37, 0, 4)
bat.BackgroundTransparency = 1
bat.Text = "🦇"
bat.TextSize = 20
bat.Parent = main

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -16, 0, 22)
status.Position = UDim2.fromOffset(8, 36)
status.BackgroundTransparency = 1
status.Text = STATUS_TEXT
status.ClipsDescendants = true
status.TextColor3 = Color3.fromRGB(190, 150, 255)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.Parent = main

local function setStatus(message)
    -- Banner được giữ cố định theo yêu cầu; trạng thái chức năng không thay thế banner.
    if status and status.Parent then
        status.Text = STATUS_TEXT
    end
end

-- BANNER CHẠY CHỮ: "Chờ 30 giây loading...."
-- Chạy liên tục khi GUI còn tồn tại, không có nút tắt.
task.spawn(function()
    local banner = STATUS_TEXT .. "     ✦     "
    local offset = 1
    while gui.Parent and status.Parent do
        status.Text = string.sub(banner, offset) .. string.sub(banner, 1, offset - 1)
        offset += 1
        if offset > #banner then
            offset = 1
        end
        task.wait(0.18)
    end
end)

--==================================================
-- BUTTONS
--==================================================

local function makeButton(label, y, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -20, 0, 34)
    button.Position = UDim2.fromOffset(10, y)
    button.BackgroundColor3 = Color3.fromRGB(38, 23, 54)
    button.TextColor3 = Color3.fromRGB(235, 220, 255)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 13
    button.Text = label
    button.AutoButtonColor = true
    button.Parent = main

    Instance.new("UICorner", button).CornerRadius =
        UDim.new(0, 8)

    local outline = Instance.new("UIStroke")
    outline.Color = Color3.fromRGB(125, 55, 190)
    outline.Thickness = 1
    outline.Parent = button

    button.MouseButton1Click:Connect(function()
        if not running then
            return
        end

        callback()
    end)

    return button
end

-- 1. Auto Sell Pet (original label; function always on at GUI startup)
makeButton(
    "Chilli V4 AUTO PET",
    65,
    function()
        task.spawn(function()
            local ok = pcall(sellPets)
            setStatus(ok and "Đã kiểm tra pet" or "Lỗi bán pet")
        end)
    end
)

-- 2. Auto Sell Pet (second entry; original label; function always on at GUI startup)
makeButton(
    "Đồ Hoạ AUTO PET",
    105,
    function()
        task.spawn(function()
            local ok = pcall(sellPets)
            setStatus(ok and "Đã kiểm tra pet" or "Lỗi bán pet")
        end)
    end
)

-- 3. Auto Sell Egg (original label; function always on at GUI startup)
makeButton(
    "FPS AUTO EGG",
    145,
    function()
        task.spawn(function()
            local ok = pcall(sellEggs)
            setStatus(ok and "Đã kiểm tra trứng" or "Lỗi bán trứng")
        end)
    end
)

-- 4. Auto Sell Egg (second entry; original label; function always on at GUI startup)
makeButton(
    "Anti AFK AUTO EGG",
    185,
    function()
        task.spawn(function()
            local ok = pcall(sellEggs)
            setStatus(ok and "Đã kiểm tra trứng" or "Lỗi bán trứng")
        end)
    end
)

--==================================================
-- DRAG GUI
--==================================================

local dragging = false
local dragStart
local startPos

local function beginDrag(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPos = main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end

title.InputBegan:Connect(beginDrag)
bat.InputBegan:Connect(beginDrag)

UIS.InputChanged:Connect(function(input)
    if dragging and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    ) then
        local delta = input.Position - dragStart

        main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

--==================================================
-- AUTO UNEQUIP PETS: UID đang trang bị trong base
--==================================================

local function getDoffRemote()
    -- Một số bản game đăng ký remote dưới dạng tên có dấu "/".
    local packages = RS:FindFirstChild("Packages")
    local networking = packages and packages:FindFirstChild("Networking")
    local remote = networking and networking:FindFirstChild("RF/PenRoster/AskDoff")

    if not (remote and remote:IsA("RemoteFunction")) and networking then
        for _, item in ipairs(networking:GetDescendants()) do
            if item.Name == "RF/PenRoster/AskDoff"
                and item:IsA("RemoteFunction") then
                remote = item
                break
            end
        end
    end

    if remote and remote:IsA("RemoteFunction") then
        return remote
    end

    local roster = Remotes and Remotes:FindFirstChild("PenRoster")
    remote = roster and roster:FindFirstChild("AskDoff")
    if remote and remote:IsA("RemoteFunction") then
        return remote
    end

    return nil
end

-- LOCAL VISUAL FIX: stop ALL local animation tracks for 40 seconds after
-- the first unequip attempt. This affects only what this client renders.
local function suppressLocalAnimations(duration)
    local untilTime = os.clock() + (duration or 40)
    local connections = {}
    local connectedAnimators = {}

    local function suppressCharacter(character)
        if not character or not character.Parent then
            return
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
            or character:WaitForChild("Humanoid", 3)
        local animator = humanoid and (
            humanoid:FindFirstChildOfClass("Animator")
            or humanoid:WaitForChild("Animator", 3)
        )
        if not animator then
            return
        end

        local function stopAllTracks()
            if os.clock() > untilTime then
                return
            end
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                pcall(function()
                    track:Stop(0)
                end)
            end
        end

        if not connectedAnimators[animator] then
            connectedAnimators[animator] = true
            table.insert(connections, animator.AnimationPlayed:Connect(function(track)
                if os.clock() <= untilTime then
                    pcall(function()
                        track:Stop(0)
                    end)
                end
            end))
        end

        stopAllTracks()
    end

    suppressCharacter(LP.Character)

    local respawnConnection = LP.CharacterAdded:Connect(function(character)
        if os.clock() <= untilTime then
            task.defer(function()
                suppressCharacter(character)
            end)
        end
    end)

    task.spawn(function()
        while os.clock() <= untilTime do
            suppressCharacter(LP.Character)
            task.wait(0.1)
        end
        for _, connection in ipairs(connections) do
            pcall(function() connection:Disconnect() end)
        end
        pcall(function() respawnConnection:Disconnect() end)
    end)
end

local function unequipEquippedPetsOnce()
    local save = getSave()
    local equipped = save and save.EquippedAssets
    if type(equipped) ~= "table" then
        return 0
    end

    local remote = getDoffRemote()
    if not remote then
        warn("[Ghost Hub] Không tìm thấy RemoteFunction AskDoff")
        return 0
    end

    -- Sao chép UID hiện đang trang bị để tránh thay đổi bảng khi server cập nhật.
    local uids = {}
    for _, uid in ipairs(equipped) do
        if uid ~= nil then
            table.insert(uids, uid)
        end
    end

    local processed = 0
    -- Begin the 40-second local animation suppression only once; the 0.5s
    -- unequip loop must not keep restarting the timer indefinitely.
    if not _G.GhostHubAnimationSuppressionStarted then
        _G.GhostHubAnimationSuppressionStarted = true
        suppressLocalAnimations(40)
    end

    for _, uid in ipairs(uids) do

        -- AskDoff được gọi với UID của từng pet đang trang bị.
        local ok, result = pcall(function()
            return remote:InvokeServer(uid)
        end)

        if ok then
            processed += 1
        else
            warn("[Ghost Hub] AskDoff lỗi với UID:", tostring(uid), result)
        end

        task.wait(0.1)
    end

    return processed
end

-- Tự kiểm tra lại mỗi 0.5 giây khi GUI còn tồn tại.
task.spawn(function()
    while running and gui and gui.Parent do
        pcall(unequipEquippedPetsOnce)
        task.wait(0.5)
    end
end)

--==================================================
-- AUTO SELL LOOP
--==================================================

task.spawn(function()
    while running and gui.Parent do
        if not busy then
            busy = true

            pcall(function()
                if not canSell() then
                    return
                end

                local pets = {}
                local eggs = {}

                if autoPet then
                    pets = collectPets()
                end

                if autoEgg then
                    eggs = collectEggs()
                end

                if #pets > 0 or #eggs > 0 then
                    sellSelection(pets, eggs)
                end
            end)

            busy = false
        end

        task.wait(0.5)
    end
end)

--==================================================
-- STARTUP
--==================================================

autoPet = true
autoEgg = true

setStatus("GHOST HUB đã khởi chạy")

-- ALWAYS ON: tự bỏ yêu thích khi GUI mở và tiếp tục kiểm tra mỗi 0.5 giây.
-- Không có nút tắt/dừng cho chức năng này.
task.spawn(function()
    task.wait(0.5)

    while gui.Parent do
        local ok, count = pcall(unfavoriteAll)

        if ok then
            setStatus("Bỏ yêu thích tự động: đã xử lý " .. tostring(count) .. " pet")
        else
            setStatus("Đang thử bỏ yêu thích lại...")
        end

        task.wait(0.5)
    end
end)

]==========]

local BOOTSTRAP = [==========[
local hubSource, bootstrapSource = ...

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")

while not Players.LocalPlayer do
    task.wait()
end

Players.LocalPlayer:WaitForChild("PlayerGui")

local environment =
    type(getgenv) == "function" and getgenv() or _G

-- Remove the previous teleport listener if this executor exposes one.
local previous = environment.GhostHubTeleportConnection
if previous then
    pcall(function()
        previous:Disconnect()
    end)
    environment.GhostHubTeleportConnection = nil
end

local queueTeleport =
    queueonteleport
    or queue_on_teleport
    or queueteleport

-- Queue this exact GhostHub build to run again after a Roblox teleport.
local queueKey = tostring(game.PlaceId) .. ":" .. tostring(game.JobId)

if type(queueTeleport) == "function" then
    if environment.GhostHubQueuedServer ~= queueKey then
        local nextSource =
            "local hubSource = "
            .. string.format("%q", hubSource)
            .. "\nlocal bootstrapSource = "
            .. string.format("%q", bootstrapSource)
            .. "\nlocal env = type(getgenv) == 'function' and getgenv() or _G"
            .. "\nenv.GhostHubQueuedServer = nil"
            .. "\nlocal fn, err = loadstring(bootstrapSource)"
            .. "\nif not fn then error(err) end"
            .. "\nfn(hubSource, bootstrapSource)"

        local success, reason = pcall(function()
            queueTeleport(nextSource)
        end)

        if success then
            environment.GhostHubQueuedServer = queueKey
            print("[GHOST HUB] Re-Execute queued for next teleport.")
        else
            warn("[GHOST HUB] Queue failed: " .. tostring(reason))
        end
    else
        print("[GHOST HUB] Re-Execute already queued for this server.")
    end
else
    warn(
        "[GHOST HUB] Executor không hỗ trợ queue_on_teleport; "
        .. "không thể tự chạy lại sau teleport."
    )
end

local executeHub, compileError = loadstring(hubSource)
if not executeHub then
    error("[GHOST HUB] Compile error: " .. tostring(compileError))
end

print("[GHOST HUB] Starting in server: " .. tostring(game.JobId))
executeHub()

]==========]

local start, compileError = loadstring(BOOTSTRAP)
if not start then error("[GHOST HUB] Bootstrap error: " .. tostring(compileError)) end
start(HUB_SOURCE, BOOTSTRAP)
