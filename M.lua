local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

local HumanModCons = {}

local function setWalkSpeed(speed)
    if typeof(speed) == "number" then
        local Char = player.Character or workspace:FindFirstChild(player.Name)
        local Human = Char and Char:FindFirstChildWhichIsA("Humanoid")
        local function WalkSpeedChange()
            if Char and Human then
                Human.WalkSpeed = speed
            end
        end
        WalkSpeedChange()
        if HumanModCons.wsLoop then
            HumanModCons.wsLoop:Disconnect()
            HumanModCons.wsLoop = nil
        end
        if HumanModCons.wsCA then
            HumanModCons.wsCA:Disconnect()
            HumanModCons.wsCA = nil
        end
        if Human then
            HumanModCons.wsLoop = Human:GetPropertyChangedSignal("WalkSpeed"):Connect(WalkSpeedChange)
        end
        HumanModCons.wsCA = player.CharacterAdded:Connect(function(nChar)
            Char, Human = nChar, nChar:WaitForChild("Humanoid")
            WalkSpeedChange()
            if HumanModCons.wsLoop then
                HumanModCons.wsLoop:Disconnect()
                HumanModCons.wsLoop = nil
            end
            HumanModCons.wsLoop = Human:GetPropertyChangedSignal("WalkSpeed"):Connect(WalkSpeedChange)
        end)
    end
end

local function createDebugPart(cf)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.Size = Vector3.new(1,1,1)
    p.Transparency = 0.5
    p.BrickColor = BrickColor.new("Really red")
    p.CFrame = cf
    p.Name = "PathDebugPart"
    p.Parent = workspace
    task.delay(1, function() if p then p:Destroy() end end)
end

local function pathTo(position)
    setWalkSpeed(50)
    local path = PathfindingService:CreatePath()
    path:ComputeAsync(hrp.Position, position)
    if path.Status ~= Enum.PathStatus.Success then return false end
    local waypoints = path:GetWaypoints()
    for _, waypoint in ipairs(waypoints) do
        if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
        createDebugPart(CFrame.new(waypoint.Position))
        humanoid:MoveTo(waypoint.Position)
        local reached = humanoid.MoveToFinished:Wait()
        if not reached then return false end
    end
    return true
end

local function holdPrompt()
    local h = false
    while true do
        task.wait(0.1)
        if h then continue end
        local pr, d = nil, 15
        for _, pl in ipairs(workspace:WaitForChild("Plots"):GetChildren()) do
            for _, v in ipairs(pl:GetDescendants()) do
                if v:IsA("ProximityPrompt") and v.Enabled then
                    local bp = v.Parent
                    while bp and not bp:IsA("BasePart") do
                        bp = bp.Parent
                    end
                    if bp and bp:IsA("BasePart") then
                        local dist = (hrp.Position - bp.Position).Magnitude
                        if dist < d then
                            d = dist
                            pr = v
                        end
                    end
                end
            end
        end
        if pr and not pr:IsDescendantOf(character) then
            h = true
            task.spawn(function()
                pcall(function()
                    if pr and pr.Parent and pr.Enabled then
                        pr:InputHoldBegin()
                        task.wait(pr.HoldDuration + 0.1)
                        pr:InputHoldEnd()
                    end
                end)
                h = false
            end)
        end
    end
end

local function getDeliveryHitbox()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in pairs(plots:GetChildren()) do
        local sign = plot:FindFirstChild("PlotSign")
        if sign and sign:FindFirstChild("YourBase") and sign.YourBase.Enabled then
            return plot:FindFirstChild("DeliveryHitbox"), plot
        end
    end
    return nil
end

local function walkOutSteps(targetPos)
    setWalkSpeed(50)
    local direction = (targetPos - hrp.Position).Unit
    for step = 1, 10 do
        local stepPos = hrp.Position + direction * 5 * step + Vector3.new(0, 2, 0)
        local success = pathTo(stepPos)
        if not success then break end
        task.wait(0.15)
    end
end

local function exitBase()
    local target, plot = getDeliveryHitbox()
    if not target then return false end
    walkOutSteps(target.Position)
    if hrp:FindFirstChild("FloatVelocity") then hrp.FloatVelocity:Destroy() end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    local bv = Instance.new("BodyVelocity")
    bv.Name = "FloatVelocity"
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not target or not target:IsDescendantOf(workspace) then
            connection:Disconnect()
            bv:Destroy()
            return
        end
        local dir = (target.Position - hrp.Position).Unit
        bv.Velocity = dir * 38
        if (hrp.Position - target.Position).Magnitude < 5 then
            connection:Disconnect()
            bv:Destroy()
            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        end
    end)
    repeat task.wait() until (hrp.Position - target.Position).Magnitude < 6
    return true
end

local function findPlotByName(name)
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in pairs(plots:GetChildren()) do
        local sign = plot:FindFirstChild("PlotSign")
        if sign and sign:FindFirstChild("SurfaceGui") and sign.SurfaceGui:FindFirstChild("Frame") and sign.SurfaceGui.Frame:FindFirstChild("TextLabel") then
            local textLabel = sign.SurfaceGui.Frame.TextLabel
            if textLabel.Text:lower():find(name:lower()) then
                return plot
            end
        end
    end
    return nil
end

local PlayersGui = player:WaitForChild("PlayerGui")
local screenGui = Instance.new("ScreenGui", PlayersGui)
screenGui.Name = "PlotSearchGui"
screenGui.ResetOnSpawn = false

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 320, 0, 120)
frame.Position = UDim2.new(0.5, -160, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.AnchorPoint = Vector2.new(0, 0)
local corner = Instance.new("UICorner", frame)
corner.CornerRadius = UDim.new(0, 10)

local textbox = Instance.new("TextBox", frame)
textbox.PlaceholderText = "Enter Player Name"
textbox.Size = UDim2.new(1, -20, 0, 50)
textbox.Position = UDim2.new(0, 10, 0, 15)
textbox.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
textbox.TextColor3 = Color3.new(1,1,1)
textbox.Font = Enum.Font.GothamBold
textbox.TextSize = 24
textbox.ClearTextOnFocus = false
local tCorner = Instance.new("UICorner", textbox)
tCorner.CornerRadius = UDim.new(0, 6)

local startButton = Instance.new("TextButton", frame)
startButton.Size = UDim2.new(1, -20, 0, 40)
startButton.Position = UDim2.new(0, 10, 0, 75)
startButton.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
startButton.Text = "Start Stealing"
startButton.TextColor3 = Color3.new(1,1,1)
startButton.Font = Enum.Font.GothamBold
startButton.TextSize = 22
local bCorner = Instance.new("UICorner", startButton)
bCorner.CornerRadius = UDim.new(0, 6)

local function waitForPromptComplete()
    repeat
        task.wait(0.1)
        local nearPrompt = false
        for _, pl in ipairs(workspace:WaitForChild("Plots"):GetChildren()) do
            for _, v in ipairs(pl:GetDescendants()) do
                if v:IsA("ProximityPrompt") and v.Enabled then
                    local bp = v.Parent
                    while bp and not bp:IsA("BasePart") do
                        bp = bp.Parent
                    end
                    if bp and bp:IsA("BasePart") then
                        if (hrp.Position - bp.Position).Magnitude < 3 then
                            nearPrompt = true
                            break
                        end
                    end
                end
            end
            if nearPrompt then break end
        end
    until not nearPrompt
end

local stealing = false

startButton.MouseButton1Click:Connect(function()
    if stealing then return end
    stealing = true
    startButton.Text = "Working..."
    startButton.Active = false
    local targetName = textbox.Text
    if targetName == "" then
        startButton.Text = "Enter Player Name"
        startButton.Active = true
        stealing = false
        return
    end
    local plotTarget = findPlotByName(targetName)
    if not plotTarget then
        startButton.Text = "Plot not found"
        startButton.Active = true
        stealing = false
        return
    end
    coroutine.wrap(holdPrompt)()
    while stealing do
        local animalPodiums = plotTarget:FindFirstChild("AnimalPodiums")
        if not animalPodiums then break end
        for i = 1, 10 do
            if not stealing then break end
            local animalModel = animalPodiums:FindFirstChild(tostring(i))
            if not animalModel then break end
            local pos = animalModel.PrimaryPart and animalModel.PrimaryPart.Position or animalModel:GetModelCFrame().p
            local success = pathTo(pos)
            if not success then break end
            task.wait(0.3)
            waitForPromptComplete()
            task.wait(0.5)
            local exitSuccess = exitBase()
            if not exitSuccess then break end
            task.wait(2)
        end
        break
    end
    startButton.Text = "Done"
    startButton.Active = true
    stealing = false
end)
