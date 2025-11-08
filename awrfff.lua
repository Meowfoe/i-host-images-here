-- LocalScript: Candy teleporter + boss proximity RollEvent
-- Place in StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local guiParent = player:WaitForChild("PlayerGui")

-- CONFIG
local CONTAINER_NAME = "CandyContainer"
local TARGET_NAME = "Candy"           -- MeshPart name
local AUTO_INTERVAL = 0.1             -- seconds between auto-teleports (requested)
local TELEPORT_OFFSET = Vector3.new(0, 3, 0)
local BOSS_NAME = "HalloweenBoss"     -- model name to monitor in workspace
local CLOSE_DISTANCE = 10             -- studs for "close" (adjust if you want)

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

-- RollEvent firing helper (handles RemoteEvent / BindableEvent / RemoteFunction)
local RollEvent = ReplicatedStorage:FindFirstChild("RollEvent")
local function fireRollEvent(bossModel)
	if not RollEvent then
		return false, "RollEvent not found in ReplicatedStorage"
	end
	local ok, res
	if RollEvent:IsA("RemoteEvent") then
		ok, res = pcall(function() RollEvent:FireServer(bossModel and bossModel.Name or nil) end)
	elseif RollEvent:IsA("BindableEvent") then
		ok, res = pcall(function() RollEvent:Fire(bossModel and bossModel.Name or nil) end)
	elseif RollEvent:IsA("RemoteFunction") then
		ok, res = pcall(function() return RollEvent:InvokeServer(bossModel and bossModel.Name or nil) end)
	else
		return false, "RollEvent is not a supported event type"
	end
	return ok, res
end

-- helper: get a useful part from a model (PrimaryPart or first BasePart)
local function getModelPart(model)
	if not model or not model:IsA("Model") then return nil end
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then return model.PrimaryPart end
	for _,v in ipairs(model:GetDescendants()) do
		if v:IsA("BasePart") then return v end
	end
	return nil
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

-- auto loop + boss proximity check (non-blocking)
local stopping = false
local bossPreviouslyClose = false

task.spawn(function()
	while not stopping and screen.Parent do
		if auto then
			-- Teleport to candy if present
			local part, err = findCandy()
			if part then
				local ok, e = teleportToTarget(part)
				if ok then
					status.Text = "Auto-teleported to Candy."
				else
					status.Text = "Auto teleport failed: "..tostring(e)
				end
			else
				status.Text = "Auto: Candy missing ("..tostring(err)..")"
			end

			-- Boss proximity check
			local boss = workspace:FindFirstChild(BOSS_NAME)
			if boss and boss:IsA("Model") then
				local bossPart = getModelPart(boss)
				local char = player.Character
				local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart"))
				if bossPart and hrp then
					local ok, dist = pcall(function() return (bossPart.Position - hrp.Position).Magnitude end)
					if ok and dist then
						if dist <= CLOSE_DISTANCE then
							if not bossPreviouslyClose then
								-- entered proximity: fire the RollEvent
								local firedOk, firedRes = fireRollEvent(boss)
								if firedOk then
									-- optional: show a quick status update
									status.Text = "Boss close — RollEvent fired."
								else
									status.Text = "RollEvent failed: "..tostring(firedRes)
								end
								bossPreviouslyClose = true
							end
						else
							-- boss is not close; reset flag
							if bossPreviouslyClose then
								bossPreviouslyClose = false
							end
						end
					end
				end
			else
				-- boss not found
				-- don't spam status; keep minimal
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
