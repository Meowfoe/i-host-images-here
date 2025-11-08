-- LocalScript: Smart Candy auto-teleport + RollEvent spam + Panic + Camera-facing
-- Place in StarterPlayer > StarterPlayerScripts

-- VERSION: 1
-- IMPORTANT: increment SCRIPT_VERSION when you make permanent script changes.
local SCRIPT_VERSION = 1

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local guiParent = player:WaitForChild("PlayerGui")
local workspace = workspace

-- CONFIG
local GUI_NAME = "CandyContainerTeleporter"
local CONTAINER_NAME = "CandyContainer"      -- where candy parts live
local CANDY_NAME_SUB = "candy"               -- substring to match candy names (case-insensitive)
local AUTO_INTERVAL = 0.1                    -- seconds between auto-teleports
local TELEPORT_OFFSET = Vector3.new(0, 3, 0) -- small offset to place above candy
local BOSS_NAME = "HalloweenBoss"
local CLOSE_DISTANCE = 100                   -- UPDATED: RollEvent spam proximity (studs)
local PANIC_DISTANCE = 10                    -- panic threshold (higher priority)
local PANIC_ESCAPE_DISTANCE = 30             -- how far to push player away on panic
local PANIC_COOLDOWN = 0.5                   -- seconds between panic teleports
local ROLL_SPAM_INTERVAL = 0.2               -- UPDATED: spam speed when roll spam enabled
local BOSS_VERTICAL_TOLERANCE = 10           -- ± studs from boss Y allowed for candies
local TELEPORTED_FLAG_NAME = "Teleported"    -- BoolValue name put inside candy once touched

-- cleanup old GUI
local old = guiParent:FindFirstChild(GUI_NAME)
if old then old:Destroy() end

-- UI
local screen = Instance.new("ScreenGui", guiParent)
screen.Name = GUI_NAME
screen.ResetOnSpawn = false

local frame = Instance.new("Frame", screen)
frame.Size = UDim2.new(0, 340, 0, 170) -- made taller to fit version UI
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
title.Text = "Smart Candy TP + Roll Spam + Panic"

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

local autoBtn = Instance.new("TextButton", frame)
autoBtn.Size = UDim2.new(0.33, -8, 0, 36)
autoBtn.Position = UDim2.new(0, 6, 0, 60)
autoBtn.Text = "Auto: OFF"
autoBtn.Font = Enum.Font.SourceSansBold
autoBtn.TextSize = 14

local nowBtn = Instance.new("TextButton", frame)
nowBtn.Size = UDim2.new(0.33, -8, 0, 36)
nowBtn.Position = UDim2.new(0.33, 2, 0, 60)
nowBtn.Text = "Teleport Now"
nowBtn.Font = Enum.Font.SourceSans
nowBtn.TextSize = 14

local rollBtn = Instance.new("TextButton", frame)
rollBtn.Size = UDim2.new(0.33, -8, 0, 36)
rollBtn.Position = UDim2.new(0.66, -16, 0, 60)
rollBtn.Text = "Roll Spam: OFF"
rollBtn.Font = Enum.Font.SourceSansBold
rollBtn.TextSize = 14

-- VERSION UI (new)
local versionLabel = Instance.new("TextLabel", frame)
versionLabel.Size = UDim2.new(0, 140, 0, 20)
versionLabel.Position = UDim2.new(0, 6, 0, 104)
versionLabel.BackgroundTransparency = 1
versionLabel.Font = Enum.Font.SourceSans
versionLabel.TextSize = 14
versionLabel.TextColor3 = Color3.fromRGB(180,180,180)
versionLabel.TextXAlignment = Enum.TextXAlignment.Left

-- small bump button to increment version at runtime (useful for testing)
local bumpBtn = Instance.new("TextButton", frame)
bumpBtn.Size = UDim2.new(0, 70, 0, 20)
bumpBtn.Position = UDim2.new(0, 152, 0, 104)
bumpBtn.Font = Enum.Font.SourceSansBold
bumpBtn.TextSize = 12
bumpBtn.Text = "Bump v+1"
bumpBtn.AutoButtonColor = true

local noteLabel = Instance.new("TextLabel", frame)
noteLabel.Size = UDim2.new(1, -12, 0, 30)
noteLabel.Position = UDim2.new(0, 6, 0, 126)
noteLabel.BackgroundTransparency = 1
noteLabel.Font = Enum.Font.SourceSans
noteLabel.TextSize = 11
noteLabel.TextColor3 = Color3.fromRGB(160,160,160)
noteLabel.TextWrapped = true
noteLabel.Text = "Tip: For a permanent version increase, edit the SCRIPT_VERSION constant at the top of this script."

-- helpers
local function safeFindContainer()
	return workspace:FindFirstChild(CONTAINER_NAME)
end

local function isCandyPart(obj)
	if not obj then return false end
	if not obj:IsA("BasePart") then return false end
	local name = tostring(obj.Name):lower()
	return name:find(CANDY_NAME_SUB, 1, true) ~= nil
end

local function collectEligibleCandies(bossY)
	local container = safeFindContainer()
	if not container then return {} end
	local out = {}
	for _,v in ipairs(container:GetDescendants()) do
		if v:IsA("BasePart") and isCandyPart(v) then
			-- skip already-teleported flagged ones
			if not v:FindFirstChild(TELEPORTED_FLAG_NAME) then
				-- vertical check relative to boss
				local ok, dy = pcall(function() return math.abs(v.Position.Y - bossY) end)
				if ok and dy and dy <= BOSS_VERTICAL_TOLERANCE then
					table.insert(out, v)
				end
			end
		end
	end
	return out
end

local function randomChoice(list)
	if not list or #list == 0 then return nil end
	-- better randomness seed
	local s = tick() * 1000 + #list + math.random(1, 1000)
	math.randomseed(s)
	return list[math.random(1, #list)]
end

local function teleportToPart(part)
	if not part or not part:IsDescendantOf(workspace) then return false, "invalid target" end
	local char = player.Character
	if not char then return false, "no char" end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false, "no HRP" end
	local ok, err = pcall(function()
		hrp.CFrame = part.CFrame + TELEPORT_OFFSET
	end)
	return ok, err
end

-- after teleporting to a candy, wait for player's character to touch it, then mark it
local function attachTouchFlag(part)
	if not part or not part:IsDescendantOf(workspace) then return end
	if part:FindFirstChild(TELEPORTED_FLAG_NAME) then return end

	local conn
	local timeout = 10 -- seconds to wait for touch (to avoid leaking connections)
	local start = tick()

	conn = part.Touched:Connect(function(hit)
		if not hit then return end
		local hParent = hit.Parent
		if not hParent then return end
		-- check if touch is from this player's character
		if hParent == player.Character then
			-- set BoolValue flag
			if not part:FindFirstChild(TELEPORTED_FLAG_NAME) then
				local v = Instance.new("BoolValue")
				v.Name = TELEPORTED_FLAG_NAME
				v.Value = true
				v.Parent = part
			end
			if conn then conn:Disconnect() end
		end
	end)

	-- small cleanup loop to disconnect after timeout if not touched
	task.spawn(function()
		while conn and conn.Connected and (tick() - start) < timeout do
			task.wait(0.25)
		end
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end)
end

-- RollEvent helper
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

-- Panic teleport: move player away from boss by PANIC_ESCAPE_DISTANCE
local lastPanic = 0
local function tryPanicTeleport(bossPart)
	if not bossPart then return false end
	local char = player.Character
	if not char then return false end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	local ok, dist = pcall(function() return (bossPart.Position - hrp.Position).Magnitude end)
	if not ok or not dist then return false end
	if dist > PANIC_DISTANCE then return false end
	-- cooldown
	if tick() - lastPanic < PANIC_COOLDOWN then return false end

	-- compute direction from boss -> player, normalize
	local dir = (hrp.Position - bossPart.Position)
	if dir.Magnitude <= 0.01 then
		dir = Vector3.new(0, 0, 1)
	end
	local unit = dir.Unit
	local newPos = hrp.Position + unit * PANIC_ESCAPE_DISTANCE
	-- keep current Y to avoid weird vertical teleport; add small upward offset to avoid stuck
	newPos = Vector3.new(newPos.X, hrp.Position.Y + 1.5, newPos.Z)

	local ok2, err = pcall(function()
		hrp.CFrame = CFrame.new(newPos)
	end)
	if ok2 then
		lastPanic = tick()
		return true
	else
		return false
	end
end

-- main behaviors
local auto = false
local rollSpamEnabled = false

-- version state for runtime (starts from SCRIPT_VERSION)
local displayVersion = SCRIPT_VERSION
local function updateVersionLabel()
	versionLabel.Text = ("Version: v%d"):format(displayVersion)
end
updateVersionLabel()

-- runtime bump (does not persist across server restarts; edit SCRIPT_VERSION for a permanent change)
bumpBtn.MouseButton1Click:Connect(function()
	displayVersion = displayVersion + 1
	updateVersionLabel()
	status.Text = ("Version bumped to v%d (runtime only). Edit SCRIPT_VERSION for permanent change."):format(displayVersion)
end)

autoBtn.MouseButton1Click:Connect(function()
	auto = not auto
	autoBtn.Text = auto and "Auto: ON" or "Auto: OFF"
end)

nowBtn.MouseButton1Click:Connect(function()
	local boss = workspace:FindFirstChild(BOSS_NAME)
	local bossPart = boss and getModelRepresentativePart(boss)
	if not bossPart then
		status.Text = "Boss not found; can't pick candies relative to boss."
		return
	end
	local candies = collectEligibleCandies(bossPart.Position.Y)
	if #candies == 0 then
		status.Text = "No eligible candies near boss."
		return
	end
	local pick = randomChoice(candies)
	local ok, err = teleportToPart(pick)
	if ok then
		status.Text = "Teleported to random candy."
		attachTouchFlag(pick)
	else
		status.Text = "Teleport failed: "..tostring(err)
	end
end)

rollBtn.MouseButton1Click:Connect(function()
	rollSpamEnabled = not rollSpamEnabled
	rollBtn.Text = rollSpamEnabled and "Roll Spam: ON" or "Roll Spam: OFF"
end)

-- Camera-facing: rotate camera to look at boss while keeping camera position
local cameraConn
local function startCameraFacing()
	local cam = workspace.CurrentCamera
	if not cam then return end
	cameraConn = RunService.RenderStepped:Connect(function()
		if not screen.Parent then
			-- GUI removed; stop updating camera
			if cameraConn then cameraConn:Disconnect() end
			return
		end
		local boss = workspace:FindFirstChild(BOSS_NAME)
		if not boss then return end
		local bossPart = getModelRepresentativePart(boss)
		if not bossPart then return end
		-- safely get positions
		local ok1, camPos = pcall(function() return cam.CFrame.Position end)
		local ok2, bossPos = pcall(function() return bossPart.Position end)
		if ok1 and ok2 and camPos and bossPos then
			-- set camera orientation to look at boss while preserving position
			local newCf = CFrame.new(camPos, bossPos)
			-- apply non-explosive set in pcall
			pcall(function() cam.CFrame = newCf end)
		end
	end)
end

-- Auto loop (handles Panic first, then random candy near boss)
local stopping = false
task.spawn(function()
	-- start camera-facing after spawn
	startCameraFacing()

	while not stopping and screen.Parent do
		if auto then
			local boss = workspace:FindFirstChild(BOSS_NAME)
			local bossPart = boss and getModelRepresentativePart(boss)

			-- Panic check first (higher priority)
			local panicked = false
			if bossPart then
				panicked = tryPanicTeleport(bossPart)
				if panicked then
					status.Text = "Panic teleport executed!"
					task.wait(0.12)
					task.wait(AUTO_INTERVAL)
					-- finished this iteration; continue next loop naturally
				else
					-- not panicked; attempt random candy near boss
					local candies = collectEligibleCandies(bossPart.Position.Y)
					if #candies > 0 then
						local pick = randomChoice(candies)
						local ok, err = teleportToPart(pick)
						if ok then
							status.Text = "Auto-teleported to random candy."
							attachTouchFlag(pick)
						else
							status.Text = "Auto teleport failed: "..tostring(err)
						end
					else
						status.Text = "No eligible candies near boss."
					end
					task.wait(AUTO_INTERVAL)
				end
			else
				status.Text = "Boss not found; can't pick candies."
				task.wait(AUTO_INTERVAL)
			end
		else
			task.wait(0.25)
		end
	end
end)

-- Roll spam loop (spams RollEvent at ROLL_SPAM_INTERVAL while enabled and boss is within CLOSE_DISTANCE)
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
						fireRoll(boss)
						task.wait(ROLL_SPAM_INTERVAL)
					else
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

-- cleanup
screen.Destroying:Connect(function()
	stopping = true
	if cameraConn and cameraConn.Connected then
		cameraConn:Disconnect()
	end
end)
