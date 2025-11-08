-- LocalScript: Teleport to workspace.CandyContainer.Candy
-- Place in StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local guiParent = player:WaitForChild("PlayerGui")

-- CONFIG
local CONTAINER_NAME = "CandyContainer"
local TARGET_NAME = "Candy"           -- MeshPart name
local AUTO_INTERVAL = 0.6            -- seconds between auto-teleports
local TELEPORT_OFFSET = Vector3.new(0, 3, 0)

-- clean old GUI
local old = guiParent:FindFirstChild("CandyContainerTeleporter")
if old then old:Destroy() end

-- UI
local screen = Instance.new("ScreenGui", guiParent)
screen.Name = "CandyContainerTeleporter"
screen.ResetOnSpawn = false

local frame = Instance.new("Frame", screen)
frame.Size = UDim2.new(0, 260, 0, 120)
frame.Position = UDim2.new(0, 12, 0, 60)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.ClipsDescendants = true

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, -8, 0, 28)
title.Position = UDim2.new(0, 4, 0, 4)
title.BackgroundTransparency = 1
title.Font = Enum.Font.SourceSansSemibold
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(235,235,235)
title.Text = "Candy Teleporter"

local close = Instance.new("TextButton", frame)
close.Size = UDim2.new(0, 24, 0, 24)
close.Position = UDim2.new(1, -28, 0, 4)
close.Text = "✕"
close.Font = Enum.Font.SourceSansBold
close.TextSize = 18
close.MouseButton1Click:Connect(function() screen:Destroy() end)

local status = Instance.new("TextLabel", frame)
status.Size = UDim2.new(1, -12, 0, 20)
status.Position = UDim2.new(0, 6, 0, 36)
status.BackgroundTransparency = 1
status.Font = Enum.Font.SourceSans
status.TextSize = 14
status.TextColor3 = Color3.fromRGB(200,200,200)
status.Text = "Waiting for target..."

local toggleBtn = Instance.new("TextButton", frame)
toggleBtn.Size = UDim2.new(0.5, -10, 0, 36)
toggleBtn.Position = UDim2.new(0, 6, 0, 60)
toggleBtn.Text = "Auto: OFF"
toggleBtn.Font = Enum.Font.SourceSansBold
toggleBtn.TextSize = 16

local nowBtn = Instance.new("TextButton", frame)
nowBtn.Size = UDim2.new(0.5, -10, 0, 36)
nowBtn.Position = UDim2.new(0.5, 4, 0, 60)
nowBtn.Text = "Teleport Now"
nowBtn.Font = Enum.Font.SourceSans
nowBtn.TextSize = 15

-- helper: find the Candy MeshPart
local function findCandy()
	local container = workspace:FindFirstChild(CONTAINER_NAME)
	if not container then return nil, "Container not found" end
	local target = container:FindFirstChild(TARGET_NAME)
	if not target then return nil, "Target not found" end
	if not target:IsA("BasePart") then return nil, "Target is not a BasePart" end
	return target, nil
end

-- teleport function
local function teleportToTarget(part)
	if not part or not part:IsDescendantOf(workspace) then return false, "invalid target" end
	local char = player.Character
	if not char then return false, "no character" end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false, "no HumanoidRootPart" end
	local ok, err = pcall(function()
		hrp.CFrame = part.CFrame + TELEPORT_OFFSET
	end)
	return ok, err
end

-- UI interactions
local auto = false
toggleBtn.MouseButton1Click:Connect(function()
	auto = not auto
	toggleBtn.Text = auto and "Auto: ON" or "Auto: OFF"
end)

nowBtn.MouseButton1Click:Connect(function()
	local part, err = findCandy()
	if not part then
		status.Text = "Teleport failed: "..tostring(err)
		return
	end
	local ok, e = teleportToTarget(part)
	status.Text = ok and "Teleported to Candy." or ("Teleport failed: "..tostring(e))
end)

-- auto loop
local stopping = false
task.spawn(function()
	while not stopping and screen.Parent do
		if auto then
			local part, err = findCandy()
			if part then
				local ok, e = teleportToTarget(part)
				if ok then
					status.Text = "Auto-teleported to Candy."
				else
					status.Text = "Auto teleport failed: "..tostring(e)
				end
			else
				status.Text = "Auto: target missing ("..tostring(err)..")"
			end
			task.wait(AUTO_INTERVAL)
		else
			-- when auto is off, still report presence occasionally
			local part = workspace:FindFirstChild(CONTAINER_NAME) and workspace[CONTAINER_NAME]:FindFirstChild(TARGET_NAME)
			if part then
				status.Text = "Target present."
			else
				status.Text = "Target not found."
			end
			task.wait(1)
		end
	end
end)

screen.Destroying:Connect(function() stopping = true end)
