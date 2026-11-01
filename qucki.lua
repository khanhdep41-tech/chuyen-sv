
--[[
    NHΛT KHΛNH SAE
    Transparent GUI - Delta
    - Ảnh nền rõ, không viền ngoài
    - Hai chức năng không có nền ô đen
    - Tiêu đề tím đậm: NHΛT KHΛNH SAE
    - Ẩn dòng trạng thái
    - Avatar tròn chỉ có ảnh, kéo được
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

local IMAGE_URL = "https://raw.githubusercontent.com/khanhdep41-tech/Nhat-Khanh-SAE/refs/heads/main/IMG_9880.jpeg"
local FOLDER = "NhatKhanhHub"
local IMAGE_PATH = FOLDER .. "/IMG_9880.jpeg"

-- Xóa GUI cũ
pcall(function()
    if CoreGui:FindFirstChild("NhatKhanhHub") then
        CoreGui.NhatKhanhHub:Destroy()
    end
end)

pcall(function()
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if pg and pg:FindFirstChild("NhatKhanhHub") then
        pg.NhatKhanhHub:Destroy()
    end
end)

-- Tải ảnh nền
local function getImageAsset()
    if type(writefile) ~= "function" then
        return nil
    end

    local assetFn = getcustomasset or getsynasset
    if type(assetFn) ~= "function" then
        return nil
    end

    pcall(function()
        if type(makefolder) == "function"
            and type(isfolder) == "function"
            and not isfolder(FOLDER) then
            makefolder(FOLDER)
        end
    end)

    local data

    if type(isfile) == "function"
        and type(readfile) == "function" then
        pcall(function()
            if isfile(IMAGE_PATH) then
                data = readfile(IMAGE_PATH)
            end
        end)
    end

    if not data or #data == 0 then
        local ok, result = pcall(function()
            return game:HttpGet(IMAGE_URL)
        end)

        if not ok or type(result) ~= "string"
            or #result == 0 then
            warn("[NHAT KHANH SAE] Không tải được ảnh nền.")
            return nil
        end

        data = result
        pcall(writefile, IMAGE_PATH, data)
    end

    local ok, asset = pcall(assetFn, IMAGE_PATH)

    if ok and type(asset) == "string" then
        return asset
    end

    return nil
end

local imageAsset = getImageAsset()

local function create(className, properties, parent)
    local obj = Instance.new(className)

    for key, value in pairs(properties) do
        obj[key] = value
    end

    obj.Parent = parent
    return obj
end

-- ScreenGui
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

-- GUI chính: trong suốt, không viền
local panel = create("Frame", {
    Name = "MainPanel",
    Size = UDim2.fromOffset(280, 164),
    Position = UDim2.new(1, -292, 0.48, -82),
    BackgroundColor3 = Color3.fromRGB(20, 13, 29),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Active = true,
    ZIndex = 1,
}, gui)

create("UICorner", {
    CornerRadius = UDim.new(0, 12),
}, panel)

-- Ảnh nền hiển thị rõ
if imageAsset then
    create("ImageLabel", {
        Name = "BackgroundImage",
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = imageAsset,
        ImageTransparency = 0,
        ScaleType = Enum.ScaleType.Crop,
        ZIndex = 1,
    }, panel)
end

-- Lớp phủ hoàn toàn trong suốt
create("Frame", {
    Name = "ImageShade",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 2,
}, panel)

-- Thanh tiêu đề trong suốt
local header = create("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 42),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 3,
}, panel)

-- Tiêu đề futuristic, màu tím đậm hơn
create("TextLabel", {
    Name = "Title",
    Size = UDim2.new(1, -48, 1, 0),
    Position = UDim2.fromOffset(12, 0),
    BackgroundTransparency = 1,
    Text = "NHΛT KHΛNH SAE",
    TextColor3 = Color3.fromRGB(174, 104, 238),
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextStrokeTransparency = 0.65,
    TextStrokeColor3 = Color3.fromRGB(90, 35, 145),
    ZIndex = 4,
}, header)

-- Nút đóng
local close = create("TextButton", {
    Name = "Close",
    Size = UDim2.fromOffset(26, 26),
    Position = UDim2.new(1, -32, 0, 8),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "×",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 22,
    Font = Enum.Font.GothamBold,
    ZIndex = 5,
}, header)

-- Trạng thái ẩn hoàn toàn
local status = create("TextLabel", {
    Name = "Status",
    Size = UDim2.new(1, -20, 0, 15),
    Position = UDim2.fromOffset(10, 43),
    BackgroundTransparency = 1,
    Text = "",
    Visible = false,
    ZIndex = 4,
}, panel)

-- Tạo nút chức năng không nền ô đen
local function createToggle(label, y)
    local row = create("Frame", {
        Name = "ToggleRow",
        Size = UDim2.new(1, -20, 0, 42),
        Position = UDim2.fromOffset(10, y),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, panel)

    create("TextLabel", {
        Name = "Label",
        Size = UDim2.new(1, -75, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Color3.fromRGB(0, 0, 0),
        TextSize = 12,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextStrokeTransparency = 1,
        TextStrokeColor3 = Color3.fromRGB(20, 10, 30),
        ZIndex = 4,
    }, row)

    local switch = create("TextButton", {
        Name = "Switch",
        Size = UDim2.fromOffset(49, 25),
        Position = UDim2.new(1, -59, 0.5, -12),
        BackgroundColor3 = Color3.fromRGB(70, 70, 76),
        Text = "",
        BorderSizePixel = 0,
        AutoButtonColor = true,
        ZIndex = 4,
    }, row)

    create("UICorner", {
        CornerRadius = UDim.new(1, 0),
    }, switch)

    local knob = create("Frame", {
        Name = "Knob",
        Size = UDim2.fromOffset(19, 19),
        Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 5,
    }, switch)

    create("UICorner", {
        CornerRadius = UDim.new(1, 0),
    }, knob)

    local function render(enabled)
        switch.BackgroundColor3 = enabled
            and Color3.fromRGB(35, 220, 105)
            or Color3.fromRGB(70, 70, 76)

        knob.Position = enabled
            and UDim2.new(1, -22, 0, 3)
            or UDim2.fromOffset(3, 3)
    end

    return switch, render
end

local autoOn = false
local snipeOn = false

local autoBtn, renderAuto =
    createToggle("Tự động lấy trứng", 62)

local snipeBtn, renderSnipe =
    createToggle("Săn trứng từ script khác", 111)

local function getRuntime()
    return env.__SenaV4EggRuntime
end

-- Chức năng tự động lấy trứng
autoBtn.Activated:Connect(function()
    local rt = getRuntime()

    if not rt or type(rt.setEnabled) ~= "function" then
        warn("[NHAT KHANH SAE] Sena runtime chưa sẵn sàng.")
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
    else
        warn("[NHAT KHANH SAE] " .. tostring(err))
    end
end)

-- Chức năng săn trứng từ script khác
snipeBtn.Activated:Connect(function()
    local rt = getRuntime()

    if not rt then
        warn("[NHAT KHANH SAE] Sena runtime chưa sẵn sàng.")
        return
    end

    local nextValue = not snipeOn

    local success, err = pcall(function()
        if type(rt._reconcileRunningState) == "function" then
            rt:_reconcileRunningState()
        end

        if nextValue then
            assert(
                type(rt._installSnipeHook) == "function",
                "Thiếu _installSnipeHook"
            )
            rt:_installSnipeHook()
        else
            assert(
                type(rt._removeSnipeHook) == "function",
                "Thiếu _removeSnipeHook"
            )
            rt:_removeSnipeHook()
        end
    end)

    if success then
        snipeOn = nextValue
        renderSnipe(snipeOn)
    else
        warn("[NHAT KHANH SAE] " .. tostring(err))
    end
end)

-- Kéo GUI bằng thanh tiêu đề
local dragging = false
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

UserInputService.InputChanged:Connect(function(input)
    if dragging and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    ) then
        local delta = input.Position - dragStart

        panel.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

-- Avatar tròn chỉ hiển thị ảnh
local avatar = create("ImageButton", {
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

create("UICorner", {
    CornerRadius = UDim.new(1, 0),
}, avatar)

-- Đóng GUI và hiện avatar
close.Activated:Connect(function()
    avatar.Position = UDim2.new(
        panel.Position.X.Scale,
        panel.Position.X.Offset
            + math.floor(panel.AbsoluteSize.X / 2) - 25,
        panel.Position.Y.Scale,
        panel.Position.Y.Offset
            + math.floor(panel.AbsoluteSize.Y / 2) - 25
    )

    panel.Visible = false
    avatar.Visible = true
end)

-- Kéo avatar
local avatarDragging = false
local avatarDragStart
local avatarStartPosition
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

UserInputService.InputChanged:Connect(function(input)
    if avatarDragging and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
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

print("[NHAT KHANH SAE] GUI đã tải.")
