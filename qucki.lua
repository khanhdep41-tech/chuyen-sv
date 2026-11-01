--[[
    NHAT KHANH HUB - QUICK STEAL
    Compact draggable GUI, positioned on the RIGHT side of the screen.
    Background image is downloaded from GitHub and cached locally when supported.

    Buttons:
      1) Quick Auto Steal
      2) Quick Steal Other Script

    Note: The buttons require the Sena runtime globals used below to exist.
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

-- Auto Re-Execute sau khi teleport (không bao gồm tính năng auto-hop)
local REEXECUTE_URL =
    "https://raw.githubusercontent.com/khanhdep41-tech/Nhat-Khanh-SAE/refs/heads/main/QuickNhatKhanh.lua"

local function setupReExecute()
    local queueFn
    if type(queue_on_teleport) == "function" then
        queueFn = queue_on_teleport
    elseif type(queueonteleport) == "function" then
        queueFn = queueonteleport
    elseif type(queueteleport) == "function" then
        queueFn = queueteleport
    elseif type(syn) == "table" and type(syn.queue_on_teleport) == "function" then
        queueFn = syn.queue_on_teleport
    end

    if type(queueFn) ~= "function" then
        warn("[NHAT KHANH SAE] Executor không hỗ trợ queue_on_teleport; không thể tự chạy lại sau teleport.")
        return false
    end

    local queuedCode = string.format([[
        task.spawn(function()
            for i = 1, 30 do
                if game:IsLoaded() then break end
                task.wait(1)
            end
            task.wait(2)

            local url = %q
            for attempt = 1, 10 do
                local ok, source = pcall(function()
                    return game:HttpGet(url)
                end)
                if ok and type(source) == "string" and #source > 100 then
                    local loadOK, fn = pcall(loadstring, source)
                    if loadOK and type(fn) == "function" then
                        local runOK, runErr = pcall(fn)
                        if runOK then
                            print("[NHAT KHANH SAE] Re-Execute thành công.")
                            return
                        else
                            warn("[NHAT KHANH SAE] Lỗi chạy source:", tostring(runErr))
                        end
                    else
                        warn("[NHAT KHANH SAE] Không thể load source.")
                    end
                else
                    warn("[NHAT KHANH SAE] Lần thử tải source thất bại:", attempt)
                end
                task.wait(3)
            end
            warn("[NHAT KHANH SAE] Re-Execute thất bại sau 10 lần thử.")
        end)
    ]], REEXECUTE_URL)

    local ok, err = pcall(function()
        queueFn(queuedCode)
    end)
    if not ok then
        warn("[NHAT KHANH SAE] Không thể đăng ký Re-Execute:", tostring(err))
        return false
    end
    print("[NHAT KHANH SAE] Đã đăng ký Re-Execute sau teleport.")
    return true
end

setupReExecute()

local IMAGE_URL = "https://raw.githubusercontent.com/khanhdep41-tech/Nhat-Khanh-SAE/refs/heads/main/IMG_9880.jpeg"
local FOLDER = "NhatKhanhHub"
local IMAGE_PATH = FOLDER .. "/IMG_9880.jpeg"

-- Remove previous copy
pcall(function()
    if CoreGui:FindFirstChild("NhatKhanhHub") then
        CoreGui.NhatKhanhHub:Destroy()
    end
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if pg and pg:FindFirstChild("NhatKhanhHub") then
        pg.NhatKhanhHub:Destroy()
    end
end)

local function getLocalImageAsset()
    if type(writefile) ~= "function" then
        warn("[Nhat Khanh Hub] Executor does not support writefile.")
        return nil
    end

    if type(getcustomasset) ~= "function" and type(getsynasset) ~= "function" then
        warn("[Nhat Khanh Hub] Executor does not support getcustomasset/getsynasset.")
        return nil
    end

    if type(makefolder) == "function" and type(isfolder) == "function" then
        pcall(function()
            if not isfolder(FOLDER) then
                makefolder(FOLDER)
            end
        end)
    elseif type(makefolder) == "function" then
        pcall(makefolder, FOLDER)
    end

    local imageData
    local downloaded = false

    -- Use cached image when available; otherwise fetch it from GitHub.
    if type(isfile) == "function" and isfile(IMAGE_PATH) and type(readfile) == "function" then
        local okRead, result = pcall(readfile, IMAGE_PATH)
        if okRead and type(result) == "string" and #result > 0 then
            imageData = result
        end
    end

    if not imageData then
        local okHttp, result = pcall(function()
            if type(game.HttpGet) == "function" then
                return game:HttpGet(IMAGE_URL)
            end
            error("HttpGet unavailable")
        end)

        if not okHttp or type(result) ~= "string" or #result == 0 then
            warn("[Nhat Khanh Hub] Could not download background image.")
            return nil
        end

        imageData = result
        downloaded = true
    end

    if downloaded then
        local okWrite, err = pcall(writefile, IMAGE_PATH, imageData)
        if not okWrite then
            warn("[Nhat Khanh Hub] Could not save image locally: " .. tostring(err))
        end
    end

    local assetFn = getcustomasset or getsynasset
    local okAsset, asset = pcall(assetFn, IMAGE_PATH)
    if okAsset and type(asset) == "string" then
        return asset
    end

    warn("[Nhat Khanh Hub] Local image asset could not be loaded.")
    return nil
end

local function new(className, properties, parent)
    local obj = Instance.new(className)
    for key, value in pairs(properties) do
        obj[key] = value
    end
    obj.Parent = parent
    return obj
end

local gui = Instance.new("ScreenGui")
gui.Name = "NhatKhanhHub"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local parentOK = pcall(function()
    gui.Parent = CoreGui
end)
if not parentOK or not gui.Parent then
    gui.Parent = player:WaitForChild("PlayerGui")
end

-- Small panel anchored to the right side, near the middle of the screen.
local panel = new("Frame", {
    Name = "MainPanel",
    Size = UDim2.fromOffset(340, 205),
    Position = UDim2.new(1, -352, 0.48, -102),
    BackgroundColor3 = Color3.fromRGB(20, 13, 29),
    BackgroundTransparency = 0.24,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Active = true,
    ZIndex = 1,
}, gui)

new("UICorner", { CornerRadius = UDim.new(0, 12) }, panel)

-- Background image, if local-file APIs are supported by the executor.
local imageAsset = getLocalImageAsset()
if imageAsset then
    new("ImageLabel", {
        Name = "BackgroundImage",
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0, 0),
        BackgroundTransparency = 1,
        Image = imageAsset,
        ImageTransparency = 0,
        ScaleType = Enum.ScaleType.Crop,
        ZIndex = 1,
    }, panel)
end

-- Dark overlay keeps text readable over the background.
new("Frame", {
    Name = "ImageShade",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(16, 10, 24),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 2,
}, panel)

local header = new("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = Color3.fromRGB(10, 8, 15),
    BackgroundTransparency = 0.30,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 3,
}, panel)
new("UICorner", { CornerRadius = UDim.new(0, 10) }, header)

new("TextLabel", {
    Name = "Title",
    Size = UDim2.new(1, -48, 1, 0),
    Position = UDim2.fromOffset(12, 0),
    BackgroundTransparency = 1,
    Text = "♛ Nhật Khánh SAE ♛",
    TextColor3 = Color3.fromRGB(238, 170, 255),
    TextSize = 15,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
}, header)

local close = new("TextButton", {
    Name = "Close",
    Size = UDim2.fromOffset(26, 26),
    Position = UDim2.new(1, -32, 0, 8),
    BackgroundColor3 = Color3.fromRGB(48, 37, 56),
    Text = "×",
    TextColor3 = Color3.fromRGB(245, 245, 245),
    TextSize = 19,
    Font = Enum.Font.Gotham,
    BorderSizePixel = 0,
    ZIndex = 4,
}, header)
new("UICorner", { CornerRadius = UDim.new(0, 6) }, close)

local status = new("TextLabel", {
    Name = "Status",
    Visible = true,
    Size = UDim2.new(1, -20, 0, 13),
    Position = UDim2.fromOffset(10, 39),
    BackgroundTransparency = 1,
    Text = "Ready",
    TextColor3 = Color3.fromRGB(205, 205, 210),
    TextSize = 9,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
}, panel)

local function createToggle(label, x, y, width)
    local row = new("Frame", {
        Name = "ToggleRow_" .. label,
        Size = UDim2.new(0, width, 0, 43),
        Position = UDim2.fromOffset(x, y),
        BackgroundColor3 = Color3.fromRGB(5, 5, 8),
        BackgroundTransparency = 0.28,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, panel)
    new("UICorner", { CornerRadius = UDim.new(0, 9) }, row)
    new("UIStroke", { Color = Color3.fromRGB(190, 75, 255), Transparency = 0.18, Thickness = 1 }, row)

    new("TextLabel", {
        Name = "Label",
        Size = UDim2.new(1, -54, 1, 0),
        Position = UDim2.fromOffset(9, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = width < 170 and 10 or 12,
        Font = Enum.Font.GothamSemibold,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    }, row)

    local switch = new("TextButton", {
        Name = "Switch",
        Size = UDim2.fromOffset(35, 21),
        Position = UDim2.new(1, -42, 0.5, -10),
        BackgroundColor3 = Color3.fromRGB(62, 48, 73),
        BackgroundTransparency = 0.08,
        Text = "",
        BorderSizePixel = 0,
        AutoButtonColor = false,
        ZIndex = 4,
    }, row)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, switch)
    local knob = new("Frame", {
        Name = "Knob",
        Size = UDim2.fromOffset(15, 15),
        Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = Color3.fromRGB(245, 245, 245),
        BorderSizePixel = 0,
        ZIndex = 5,
    }, switch)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)

    local function render(enabled)
        switch.BackgroundColor3 = enabled and Color3.fromRGB(190, 55, 255) or Color3.fromRGB(45, 37, 52)
        knob.Position = enabled and UDim2.new(1, -18, 0, 3) or UDim2.fromOffset(3, 3)
    end
    return switch, render
end

local autoOn, snipeOn, treadmillOn, fishOn = false, false, false, false
local rowWidth = 320
local halfWidth = 156
local autoBtn, renderAuto = createToggle("Tự Động Lấy Trứng", 10, 55, rowWidth)
local snipeBtn, renderSnipe = createToggle("Săn Trứng", 10, 101, rowWidth)
local treadmillBtn, renderTreadmill = createToggle("Tự Động Chạy Bộ", 10, 147, halfWidth)
local fishBtn, renderFish = createToggle("Tự Động Câu Cá", 174, 147, halfWidth)

local function getRuntime()
    return env.__SenaV4EggRuntime
end

autoBtn.Activated:Connect(function()
    local rt = getRuntime()
    if not rt or type(rt.setEnabled) ~= "function" then
        status.Text = "Sena runtime not found"
        warn("[Nhat Khanh Hub] Runtime missing or setEnabled unavailable.")
        return
    end

    local nextValue = not autoOn
    local success, err = pcall(function()
        rt:setEnabled(nextValue)
        if type(env.__SenaV4SetStealDeclutter) == "function" then
            env.__SenaV4SetStealDeclutter(nextValue)
        end
    end)

    if success then
        autoOn = nextValue
        renderAuto(autoOn)
        status.Text = "Tự động lấy trứng: " .. (autoOn and "BẬT" or "TẮT")
    else
        status.Text = "Auto Steal error"
        warn("[Nhat Khanh Hub] " .. tostring(err))
    end
end)

snipeBtn.Activated:Connect(function()
    local rt = getRuntime()
    if not rt then
        status.Text = "Sena runtime not found"
        warn("[Nhat Khanh Hub] Runtime missing.")
        return
    end

    local nextValue = not snipeOn
    local success, err = pcall(function()
        if type(rt._reconcileRunningState) == "function" then
            rt:_reconcileRunningState()
        end

        if nextValue then
            assert(type(rt._installSnipeHook) == "function",
                "Missing _installSnipeHook")
            rt:_installSnipeHook()
        else
            assert(type(rt._removeSnipeHook) == "function",
                "Missing _removeSnipeHook")
            rt:_removeSnipeHook()
        end
    end)

    if success then
        snipeOn = nextValue
        renderSnipe(snipeOn)
        status.Text = "Săn trứng script khác: " .. (snipeOn and "BẬT" or "TẮT")
    else
        status.Text = "Other Script hook error"
        warn("[Nhat Khanh Hub] " .. tostring(err))
    end
end)

treadmillBtn.Activated:Connect(function()
    local manager = env.__SenaV4TreadmillManager
    local nextValue = not treadmillOn
    local ok, err = pcall(function()
        assert(manager and type(manager.setIdleFarm) == "function", "Không tìm thấy bộ quản lý máy chạy bộ của Sena V7")
        manager:setIdleFarm(nextValue)
    end)
    if ok then
        treadmillOn = nextValue
        renderTreadmill(treadmillOn)
        status.Text = "Tự Động Chạy Bộ: " .. (treadmillOn and "BẬT" or "TẮT")
    else
        status.Text = "Chưa tìm thấy chức năng chạy bộ"
        warn("[Nhat Khanh Hub] " .. tostring(err))
    end
end)

fishBtn.Activated:Connect(function()
    local nextValue = not fishOn
    local setter = env.__SenaV4SetAutoFish or env.__NhatKhanhSetAutoFish
    local ok, err = pcall(function()
        assert(type(setter) == "function", "Chưa có cầu nối Auto Fish. Hãy chạy bản Sena V7 đã ghép cầu nối trước.")
        setter(nextValue)
    end)
    if ok then
        fishOn = nextValue
        renderFish(fishOn)
        status.Text = "Tự Động Câu Cá: " .. (fishOn and "BẬT" or "TẮT")
    else
        status.Text = "Cần kết nối hàm câu cá Sena V7"
        warn("[Nhat Khanh Hub] " .. tostring(err))
    end
end)

-- Drag by the header; supports mouse and touchscreen.
local dragging = false
local dragInput
local dragStart
local startPosition

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = panel.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input == dragInput
        or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

-- Nút tròn dùng TOÀN BỘ ảnh nền, không chữ và không viền
local avatar = new("ImageButton", {
    Name = "FloatingAvatar",
    Size = UDim2.fromOffset(50, 50),
    Position = UDim2.new(1, -64, 0.48, -25),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = imageAsset or "",
    ScaleType = Enum.ScaleType.Crop,
    AutoButtonColor = false,
    Visible = false,
    Active = true,
    ZIndex = 20,
}, gui)

-- Cắt ảnh thành hình tròn; không thêm chữ hay viền
new("UICorner", {
    CornerRadius = UDim.new(1, 0)
}, avatar)

close.Activated:Connect(function()
    -- Đặt avatar gần vị trí GUI trước khi ẩn
    avatar.Position = UDim2.new(
        panel.Position.X.Scale,
        panel.Position.X.Offset + math.floor(panel.AbsoluteSize.X / 2) - 24,
        panel.Position.Y.Scale,
        panel.Position.Y.Offset + math.floor(panel.AbsoluteSize.Y / 2) - 24
    )
    panel.Visible = false
    avatar.Visible = true
end)

-- Kéo avatar tròn bằng cảm ứng/chuột
local avatarDragging = false
local avatarDragStart
local avatarStartPosition
local avatarDragInput
local avatarMoved = false

avatar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        avatarDragging = true
        avatarMoved = false
        avatarDragStart = input.Position
        avatarStartPosition = avatar.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                avatarDragging = false
            end
        end)
    end
end)

avatar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        avatarDragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if avatarDragging and (
        input == avatarDragInput
        or input.UserInputType == Enum.UserInputType.MouseMovement
    ) then
        local delta = input.Position - avatarDragStart
        if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then
            avatarMoved = true
        end
        avatar.Position = UDim2.new(
            avatarStartPosition.X.Scale,
            avatarStartPosition.X.Offset + delta.X,
            avatarStartPosition.Y.Scale,
            avatarStartPosition.Y.Offset + delta.Y
        )
    end
end)

avatar.Activated:Connect(function()
    if avatarMoved then
        avatarMoved = false
        return
    end
    panel.Visible = true
    avatar.Visible = false
end)

print("[NHAT KHANH] GUI đã tải; bấm nút avatar để mở lại.")
