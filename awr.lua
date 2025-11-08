-- LocalScript: Barebones Roll Spam + WalkSpeed button + instant proximity escape
-- Place in StarterPlayer > StarterPlayerScripts

-- VERSION: 8
local SCRIPT_VERSION = 9

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local guiParent = player:WaitForChild("PlayerGui")
local workspace = workspace

-- CONFIG
local GUI_NAME = "CandyContainerTeleporter_Barebones"
local BOSS_NAME = "HalloweenBoss"
local CLOSE_DISTANCE = 100       -- distance within which roll spam will fire
local ROLL_SPAM_INTERVAL = 0.01   -- seconds between roll fires while spamming

-- PROXIMITY ESCAPE CONFIG
local PROXIMITY_THRESHOLD = 25   -- if player is within this many studs of boss -> instant escape
local ESCAPE_DISTANCE = 50       -- teleport player to this distance away from boss (studs)
local ESCAPE_Y_OFFSET = 3        -- vertical offset to place player above ground at destination
local ESCAPE_DEBOUNCE = 0.2      -- seconds debounce to avoid multi-teleports in the same moment

-- cleanup old GUI
local old = guiParent:FindFirstChild(GUI_NAME)
if old then old:Destroy() end

-- UI
local screen = Instance.new("ScreenGui", guiParent)
screen.Name = GUI_NAME
screen.ResetOnSpawn = false

local frame = Instance.new("Frame", screen)
frame.Size = UDim2.new(0, 300, 0, 110)
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
title.Text = "Roll Spam + WalkSpeed + Proximity Escape"

local close = Instance.new("TextButton", frame)
close.Size = UDim2.new(0, 24, 0, 24)
close.Position = UDim2.new(1, -28, 0, 4)
close.Text = "✕"
close.Font = Enum.Font.SourceSansBold
close.TextSize = 18
close.MouseButton1Click:Connect(function() screen:Destroy() end)

local status = Instance.new("TextLabel", frame)
status.Size = UDim2.new(1, -12, 0, 18)
status.Position = UDim2.new(0, 6, 0, 36)
status.BackgroundTransparency = 1
status.Font = Enum.Font.SourceSans
status.TextSize = 14
status.TextColor3 = Color3.fromRGB(200,200,200)
status.Text = "Ready."

local wsBtn = Instance.new("TextButton", frame)
wsBtn.Size = UDim2.new(0.5, -10, 0, 28)
wsBtn.Position = UDim2.new(0, 6, 0, 60)
wsBtn.Text = "Set WalkSpeed = 30"
wsBtn.Font = Enum.Font.SourceSansBold
wsBtn.TextSize = 14

local rollBtn = Instance.new("TextButton", frame)
rollBtn.Size = UDim2.new(0.5, -10, 0, 28)
rollBtn.Position = UDim2.new(0.5, 4, 0, 60)
rollBtn.Text = "Roll Spam: OFF"
rollBtn.Font = Enum.Font.SourceSansBold
rollBtn.TextSize = 14

local versionLabel = Instance.new("TextLabel", frame)
versionLabel.Size = UDim2.new(1, -12, 0, 18)
versionLabel.Position = UDim2.new(0, 6, 0, 92)
versionLabel.BackgroundTransparency = 1
versionLabel.Font = Enum.Font.SourceSans
versionLabel.TextSize = 12
versionLabel.TextColor3 = Color3.fromRGB(170,170,170)
versionLabel.TextXAlignment = Enum.TextXAlignment.Left
versionLabel.Text = "Version: v" .. tostring(SCRIPT_VERSION)

-- RollEvent helper (best-effort for RemoteEvent/BindableEvent/RemoteFunction)
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
		local ok, res = pcall(function() return RollEvent:InvokeServer(bossModel and bossModel.Name or nil) end)
		return ok, res
	else
		return false, "RollEvent unsupported type"
	end
end

local function getModelRepresentativePart(model)
	if not model or not model:IsA("Model") then return nil end
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then return model.PrimaryPart end
	for _,d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then return d end
	end
	return nil
end

-- WalkSpeed behavior
local desiredWalkSpeed = nil  -- if set, reapply on respawn
local function applyWalkSpeedToHumanoid(humanoid, speed)
	if not humanoid then return end
	pcall(function() humanoid.WalkSpeed = speed end)
end

wsBtn.MouseButton1Click:Connect(function()
	local char = player.Character
	local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		applyWalkSpeedToHumanoid(humanoid, 30)
		desiredWalkSpeed = 30
		status.Text = "WalkSpeed set to 30."
	else
		desiredWalkSpeed = 30
		status.Text = "Will set WalkSpeed to 30 on respawn."
	end
end)

local function onCharacterAdded(char)
	if desiredWalkSpeed then
		local humanoid = char:WaitForChild("Humanoid", 5)
		if humanoid then
			applyWalkSpeedToHumanoid(humanoid, desiredWalkSpeed)
		end
	end
end
if player.Character then onCharacterAdded(player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)

-- Roll spam loop
local stopping = false
local rollSpamEnabled = false

rollBtn.MouseButton1Click:Connect(function()
	rollSpamEnabled = not rollSpamEnabled
	rollBtn.Text = rollSpamEnabled and "Roll Spam: ON" or "Roll Spam: OFF"
	status.Text = rollSpamEnabled and "Roll spam enabled." or "Roll spam disabled."
end)

task.spawn(function()
	while not stopping and screen.Parent do
		if rollSpamEnabled then
			local boss = workspace:FindFirstChild(BOSS_NAME)
			if boss and boss:IsA("Model") then
				local bossPart = getModelRepresentativePart(boss)
				local char = player.Character
				local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart"))
				if bossPart and hrp then
					local ok, dist = pcall(function() return (bossPart.Position - hrp.Position).Magnitude end)
					if ok and dist and dist <= CLOSE_DISTANCE then
						pcall(function() fireRoll(boss) end)
						task.wait(ROLL_SPAM_INTERVAL)
					else
						task.wait(0.25)
					end
				else
					task.wait(0.4)
				end
			else
				task.wait(0.6)
			end
		else
			task.wait(0.25)
		end
	end
end)

-- Proximity watcher (Heartbeat for fastest reaction)
local lastEscape = 0
local heartbeatConn
heartbeatConn = RunService.Heartbeat:Connect(function()
	if not screen.Parent then return end
	local boss = workspace:FindFirstChild(BOSS_NAME)
	if not boss or not boss:IsA("Model") then return end
	local bossPart = getModelRepresentativePart(boss)
	if not bossPart then return end
	local char = player.Character
	local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart"))
	if not hrp then return end

	local ok, dist = pcall(function() return (bossPart.Position - hrp.Position).Magnitude end)
	if not ok or not dist then return end

	if dist <= PROXIMITY_THRESHOLD and (tick() - lastEscape) >= ESCAPE_DEBOUNCE then
		lastEscape = tick()
		-- compute random direction on XZ plane and teleport to ESCAPE_DISTANCE away from boss
		local angle = math.random() * math.pi * 2
		local dx = math.cos(angle) * ESCAPE_DISTANCE
		local dz = math.sin(angle) * ESCAPE_DISTANCE
		local targetPos = bossPart.Position + Vector3.new(dx, ESCAPE_Y_OFFSET, dz)
		-- attempt immediate teleport (best-effort)
		local okTp, err = pcall(function()
			hrp.CFrame = CFrame.new(targetPos)
		end)
		if okTp then
			status.Text = ("Proximity escape executed (%.1f studs -> %.1f studs)."):format(dist, ESCAPE_DISTANCE)
		else
			status.Text = ("Escape failed: %s"):format(tostring(err))
		end
	end
end)

-- cleanup
screen.Destroying:Connect(function()
	stopping = true
	if heartbeatConn and heartbeatConn.Connected then heartbeatConn:Disconnect() end
end)

