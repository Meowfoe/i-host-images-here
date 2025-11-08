-- Single LocalScript: Candy auto-teleport + separate RollEvent spam toggle
-- Place in StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local guiParent = player:WaitForChild("PlayerGui")

-- CONFIG
local CONTAINER_NAME = "CandyContainer"
local TARGET_NAME = "Candy"           -- MeshPart name
local AUTO_INTERVAL = 0.1             -- seconds between auto-teleports
local TELEPORT_OFFSET = Vector3.new(0, 3, 0)

local BOSS_NAME = "HalloweenBoss"     -- model name to monitor
local CLOSE_DISTANCE = 30             -- studs for "close"
local ROLL_SPAM_INTERVAL = 0.1        -- how fast to spam RollEvent when active & boss is close

-- cleanup old GUI
local GUI_NAME = "CandyContainerTeleporter"
local old = guiParent:FindFirstChild(GUI_NAME)
if old then old:Destroy() end

-- UI
local screen = Instance.new("ScreenGui", guiParent)
screen.Name = GUI_NAME
screen.ResetOnSpawn = false

local frame = Instance.new("Frame", screen)
frame.Size = UDim2.new(0, 300, 0, 140)
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
title.Text = "Candy Teleporter + Roll Spam"

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
status.Text = "Ready."

-- Buttons: Auto toggle, Teleport Now, Roll Spam toggle
local autoBtn = Instance.new("TextButton", frame)
autoBtn.Size = UDim2.new(0.5, -10, 0, 36)
autoBtn.Position = UDim2.new(0, 6, 0, 60)
autoBtn.Text = "Auto: OFF"
autoBtn.Font = Enum.Font.SourceSansBold
autoBtn.TextSize = 16

local nowBtn = Instance.new("TextButton", frame)
nowBtn.Size = UDim2.new(0.5, -10, 0, 36)
nowBtn.Position = UDim2.new(0.5, 4, 0, 60)
nowBtn.Text = "Teleport Now"
nowBtn.Font = Enum.Font.SourceSans
nowBtn.TextSize = 15

local rollBtn = Instance.new("TextButton", frame)
rollBtn.Size = UDim2.new(1, -12, 0, 28)
rollBtn.Position = UDim2.new(0, 6, 0, 102)
rollBtn.Text = "Roll Spam: OFF"
rollBtn.Font = Enum.Font.SourceSansBold
rollBtn.TextSize = 14

-- helpers
local function findCandy()
	local container = workspace:FindFirstChild(CONTAINER_NAME)
	if not container then return nil, "Container not found" end
	local target = container:FindFirstChild(TARGET_NAME)
	if not target then return nil, "Target not found" end
	if not target:IsA("BasePart") then return nil, "Target not a BasePart" end
	return target, nil
end

local function teleportTo(part)
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

-- RollEvent helper (supports RemoteEvent / BindableEvent / RemoteFunction)
local RollEvent = ReplicatedStorage:FindFirstChild("RollEvent")
local function fireRoll(bossModel)
	if not RollEvent then return false, "RollEvent not found" end
	if RollEvent:IsA("RemoteEvent") then
		local ok, res = pcall(function() RollEvent:FireServer(bossModel and bossModel.Name or nil) end)
		return ok, res
	elseif RollEvent:IsA("BindableEvent") then
		local ok, res = pcall(function() RollEvent:Fire(bossModel and bossModel.Name or nil) end)
		return ok, res
	elseif RollEvent:IsA("RemoteFunction") then
		-- RemoteFunction invokes block; still pcall but beware of server-side delay.
		local ok, res = pcall(function() return RollEvent:InvokeServer(bossModel and bossModel.Name or nil) end)
		return ok, res
	else
		return false, "RollEvent unsupported type"
	end
end

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
local rollSpamEnabled = false

autoBtn.MouseButton1Click:Connect(function()
	auto = not auto
	autoBtn.Text = auto and "Auto: ON" or "Auto: OFF"
end)

nowBtn.MouseButton1Click:Connect(function()
	local part, err = findCandy()
	if not part then
		status.Text = "Teleport failed: "..tostring(err)
		return
	end
	local ok, err2 = teleportTo(part)
	status.Text = ok and "Teleported to Candy." or ("Teleport failed: "..tostring(err2))
end)

rollBtn.MouseButton1Click:Connect(function()
	rollSpamEnabled = not rollSpamEnabled
	rollBtn.Text = rollSpamEnabled and "Roll Spam: ON" or "Roll Spam: OFF"
end)

-- Auto teleport loop
local stopping = false
task.spawn(function()
	while not stopping and screen.Parent do
		if auto then
			local part, err = findCandy()
			if part then
				local ok, e = teleportTo(part)
				if ok then
					status.Text = "Auto-teleported to Candy."
				else
					status.Text = "Auto teleport failed: "..tostring(e)
				end
			else
				status.Text = "Auto: Candy missing ("..tostring(err)..")"
			end
			task.wait(AUTO_INTERVAL)
		else
			task.wait(0.4)
		end
	end
end)

-- Roll spam loop (checks boss proximity and spams while enabled and close)
task.spawn(function()
	while not stopping and screen.Parent do
		if rollSpamEnabled then
			local boss = workspace:FindFirstChild(BOSS_NAME)
			if boss and boss:IsA("Model") then
				local bossPart = getModelPart(boss)
				local char = player.Character
				local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart"))
				if bossPart and hrp then
					local ok, dist = pcall(function() return (bossPart.Position - hrp.Position).Magnitude end)
					if ok and dist and dist <= CLOSE_DISTANCE then
						-- spam RollEvent repeatedly while enabled and boss is close
						local firedOk, firedRes = fireRoll(boss)
						if firedOk then
							-- quick status update; not spammy to UI
							status.Text = "RollEvent spam: fired."
						else
							status.Text = "RollEvent error: "..tostring(firedRes)
						end
						-- wait spam interval before possibly firing again
						task.wait(ROLL_SPAM_INTERVAL)
					else
						-- boss not close; check again shortly
						task.wait(0.2)
					end
				else
					task.wait(0.4)
				end
			else
				task.wait(0.6)
			end
		else
			task.wait(0.4)
		end
	end
end)

-- cleanup flag
screen.Destroying:Connect(function() stopping = true end)
