-- LocalScript: Smart Candy auto-teleport + RollEvent spam + Panic + Camera-facing
-- Place in StarterPlayer > StarterPlayerScripts

-- VERSION: 6
-- IMPORTANT: increment SCRIPT_VERSION when you make permanent script changes.
local SCRIPT_VERSION = 6

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
local CLOSE_DISTANCE = 100                   -- RollEvent spam proximity (studs)
local PANIC_DISTANCE = 10                    -- panic threshold (higher priority)
local PANIC_ESCAPE_DISTANCE = 30             -- how far to push player away on panic
local PANIC_COOLDOWN = 0.5                   -- seconds between panic teleports
local ROLL_SPAM_INTERVAL = 0.2               -- spam speed when roll spam enabled
local BOSS_VERTICAL_TOLERANCE = 10           -- ± studs from boss Y allowed for candies
local TELEPORTED_FLAG_NAME = "Teleported"    -- BoolValue name put inside candy once touched

-- NEW: prefer candies far from boss, avoid near candies when possible
local MIN_SAFE_TELEPORT_DISTANCE = 25        -- try to avoid teleporting to candies closer than this to the boss

-- SPECIAL ANIMATION WATCH (user request)
local TARGET_ANIM_ID = "79413205921631"     -- target animation id to watch for
local SPECIAL_WAIT = 2                       -- seconds to wait AFTER detecting animation, before firing a single roll (changed to 2)
local SPECIAL_COOLDOWN = 5                   -- seconds cooldown between special triggers

-- STOP DETECTION (kept but not primary)
local STOP_SPEED_THRESHOLD = 0.5             -- studs/sec below which boss counts as "stopped"
local ROLL_PAUSE_ON_STOP = 1.5               -- seconds to pause roll spam when boss stopped AND playing animation

-- LOW-HEALTH SAFETY
local LOW_HEALTH_THRESHOLD = 20              -- if player's HP below this -> safety
local EMERGENCY_PLATFORM_OFFSET = Vector3.new(2000, 5, 0) -- offset from current position where platform will be placed (X,Y,Z)
local EMERGENCY_PLATFORM_SIZE = Vector3.new(30, 2, 30)

-- cleanup old GUI
local old = guiParent:FindFirstChild(GUI_NAME)
if old then old:Destroy() end

-- UI
local screen = Instance.new("ScreenGui", guiParent)
screen.Name = GUI_NAME
screen.ResetOnSpawn = false

local frame = Instance.new("Frame", screen)
frame.Size = UDim2.new(0, 340, 0, 170)
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

-- VERSION UI
local versionLabel = Instance.new("TextLabel", frame)
versionLabel.Size = UDim2.new(0, 140, 0, 20)
versionLabel.Position = UDim2.new(0, 6, 0, 104)
versionLabel.BackgroundTransparency = 1
versionLabel.Font = Enum.Font.SourceSans
versionLabel.TextSize = 14
versionLabel.TextColor3 = Color3.fromRGB(180,180,180)
versionLabel.TextXAlignment = Enum.TextXAlignment.Left

local noteLabel = Instance.new("TextLabel", frame)
noteLabel.Size = UDim2.new(1, -12, 0, 30)
noteLabel.Position = UDim2.new(0, 6, 0, 126)
noteLabel.BackgroundTransparency = 1
noteLabel.Font = Enum.Font.SourceSans
noteLabel.TextSize = 11
noteLabel.TextColor3 = Color3.fromRGB(160,160,160)
noteLabel.TextWrapped = true
noteLabel.Text = "Tip: Edit the SCRIPT_VERSION constant at the top of this script for a permanent version change."

-- ANIMATION GUI (placed beneath the main frame)
local animFrame = Instance.new("Frame", screen)
animFrame.Size = UDim2.new(0, 340, 0, 36)
animFrame.Position = UDim2.new(frame.Position.X.Scale, frame.Position.X.Offset, frame.Position.Y.Scale, frame.Position.Y.Offset + frame.Size.Y.Offset + 8)
animFrame.BackgroundTransparency = 0.25
animFrame.BorderSizePixel = 0

local animLabel = Instance.new("TextLabel", animFrame)
animLabel.Size = UDim2.new(1, -12, 1, -8)
animLabel.Position = UDim2.new(0, 6, 0, 4)
animLabel.BackgroundTransparency = 1
animLabel.Font = Enum.Font.SourceSans
animLabel.TextSize = 14
animLabel.TextColor3 = Color3.fromRGB(200,200,200)
animLabel.TextXAlignment = Enum.TextXAlignment.Left
animLabel.Text = "Last Boss Anim ID: N/A"

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

-- choose farthest candy from bossPos; prefer ones further than MIN_SAFE_TELEPORT_DISTANCE if any
local function chooseFarthestCandy(list, bossPos)
	if not list or #list == 0 then return nil end
	local safeList = {}
	for _,part in ipairs(list) do
		local ok, d = pcall(function() return (part.Position - bossPos).Magnitude end)
		if ok and d then
			if d >= MIN_SAFE_TELEPORT_DISTANCE then
				table.insert(safeList, {part=part,dist=d})
			end
		end
	end
	local candidates = safeList
	if #candidates == 0 then
		-- fallback: use all candies and still pick the farthest available
		for _,part in ipairs(list) do
			local ok, d = pcall(function() return (part.Position - bossPos).Magnitude end)
			if ok and d then
				table.insert(candidates, {part=part,dist=d})
			end
		end
		if #candidates == 0 then return nil end
	end
	local best, bestDist = candidates[1].part, candidates[1].dist
	for i=2,#candidates do
		if candidates[i].dist > bestDist then
			best = candidates[i].part
			bestDist = candidates[i].dist
		end
	end
	return best
end

local function randomChoice(list)
	if not list or #list == 0 then return nil end
	local s = tick() * 1000 + #list + math.random(1, 1000)
	math.randomseed(s)
	return list[math.random(1, #list)]
end

-- safety mode flag & emergency platform ref
local safetyTeleportActive = false
local emergencyPlatform = nil
local previousAutoState = false

-- modified teleportToPart: respects safety mode
local function teleportToPart(part)
	if safetyTeleportActive then
		return false, "safety mode active - teleport blocked"
	end
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

local function teleportNowAllowed()
	return not safetyTeleportActive
end

-- after teleporting to a candy, wait for player's character to touch it, then mark it
local function attachTouchFlag(part)
	if safetyTeleportActive then return end
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

-- Emergency platform creation (anchored) and teleport player onto it
local function createEmergencyPlatformAndTeleport()
	if safetyTeleportActive then return end
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- mark safety mode
	safetyTeleportActive = true
	previousAutoState = auto
	auto = false -- disable auto-teleporting
	status.Text = "Low HP detected — safety mode active. Teleporting to safe platform..."

	-- create platform far away relative to current HRP position
	local platformPos = hrp.Position + EMERGENCY_PLATFORM_OFFSET
	local plat = Instance.new("Part")
	plat.Name = "EmergencyPlatform_" .. player.Name
	plat.Anchored = true
	plat.CanCollide = true
	plat.Size = EMERGENCY_PLATFORM_SIZE
	plat.Position = platformPos
	plat.Transparency = 0.25
	plat.Parent = workspace
	emergencyPlatform = plat

	-- teleport player above platform
	pcall(function()
		hrp.CFrame = CFrame.new(platformPos + Vector3.new(0, (EMERGENCY_PLATFORM_SIZE.Y/2) + 3, 0))
	end)
end

local function removeEmergencyPlatform()
	if emergencyPlatform and emergencyPlatform.Parent then
		pcall(function() emergencyPlatform:Destroy() end)
	end
	emergencyPlatform = nil
end

-- Health monitoring & safety logic for local player
local function monitorHumanoid(humanoid)
	if not humanoid then return end

	-- helper to decide when healed to full
	local function checkAndWaitForFullHeal()
		-- wait until health >= max health (or until humanoid removed)
		while humanoid and humanoid.Parent and humanoid.Health < humanoid.MaxHealth do
			task.wait(0.5)
		end
		-- restore state
		removeEmergencyPlatform()
		safetyTeleportActive = false
		auto = previousAutoState or false
		status.Text = "Healed to full — safety mode cleared."
	end

	-- immediate check
	if humanoid.Health < LOW_HEALTH_THRESHOLD and not safetyTeleportActive then
		createEmergencyPlatformAndTeleport()
		task.spawn(checkAndWaitForFullHeal)
	end

	-- connect HealthChanged
	local conn
	conn = humanoid.HealthChanged:Connect(function(newHealth)
		if not humanoid or not humanoid.Parent then
			if conn then conn:Disconnect() end
			return
		end
		if newHealth < LOW_HEALTH_THRESHOLD and not safetyTeleportActive then
			-- trigger safety flow
			createEmergencyPlatformAndTeleport()
			task.spawn(checkAndWaitForFullHeal)
		end
	end)

	-- cleanup when humanoid removed
	humanoid.AncestryChanged:Connect(function(_, parent)
		if not parent and conn then
			conn:Disconnect()
		end
	end)
end

-- Utility: gather all playing animation tracks from any child that implements GetPlayingAnimationTracks()
local function getAllPlayingTracks(model)
	local tracks = {}
	for _,inst in ipairs(model:GetDescendants()) do
		local ok, result = pcall(function()
			if type(inst.GetPlayingAnimationTracks) == "function" then
				return inst:GetPlayingAnimationTracks()
			end
			return nil
		end)
		if ok and result and type(result) == "table" and #result > 0 then
			for _,t in ipairs(result) do
				table.insert(tracks, t)
			end
		end
	end
	return tracks
end

-- Camera-facing: rotate camera to look at boss pivot (model) while keeping camera position
local cameraConn
local function startCameraFacing()
	local cam = workspace.CurrentCamera
	if not cam then return end
	cameraConn = RunService.RenderStepped:Connect(function()
		if not screen.Parent then
			if cameraConn then cameraConn:Disconnect() end
			return
		end
		local boss = workspace:FindFirstChild(BOSS_NAME)
		if not boss then return end

		-- try to use model pivot (more accurate "boss model" center); fallback to representative part
		local bossPos
		local okPivot, pivot = pcall(function() return boss:GetPivot() end)
		if okPivot and pivot then
			bossPos = pivot.Position
		else
			local bossPart = getModelRepresentativePart(boss)
			if bossPart then bossPos = bossPart.Position end
		end
		if not bossPos then return end

		local ok1, camPos = pcall(function() return cam.CFrame.Position end)
		if ok1 and camPos then
			local newCf = CFrame.new(camPos, bossPos)
			pcall(function() cam.CFrame = newCf end)
		end
	end)
end

-- MAIN
local auto = false
local rollSpamEnabled = false

-- version state for runtime (starts from SCRIPT_VERSION)
local displayVersion = SCRIPT_VERSION
local function updateVersionLabel()
	versionLabel.Text = ("Version: v%d"):format(displayVersion)
end
updateVersionLabel()

autoBtn.MouseButton1Click:Connect(function()
	-- if safety active, block enabling auto
	if safetyTeleportActive then
		status.Text = "Cannot enable Auto while safety mode is active."
		return
	end
	auto = not auto
	autoBtn.Text = auto and "Auto: ON" or "Auto: OFF"
end)

nowBtn.MouseButton1Click:Connect(function()
	if not teleportNowAllowed() then
		status.Text = "Teleport blocked: safety mode active."
		return
	end
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
	-- choose farthest from boss; prefer ones beyond MIN_SAFE_TELEPORT_DISTANCE
	local pick = chooseFarthestCandy(candies, bossPart.Position)
	if not pick then
		status.Text = "No suitable candy found."
		return
	end
	local ok, err = teleportToPart(pick)
	if ok then
		status.Text = "Teleported to farthest candy away from boss."
		attachTouchFlag(pick)
	else
		status.Text = "Teleport failed: "..tostring(err)
	end
end)

rollBtn.MouseButton1Click:Connect(function()
	rollSpamEnabled = not rollSpamEnabled
	rollBtn.Text = rollSpamEnabled and "Roll Spam: ON" or "Roll Spam: OFF"
end)

-- Auto loop (handles Panic first, then teleport to farthest candy near boss)
local stopping = false
task.spawn(function()
	startCameraFacing()

	while not stopping and screen.Parent do
		if auto then
			if safetyTeleportActive then
				-- safety mode active: skip teleports
				task.wait(0.5)
			else
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
					else
						-- not panicked; attempt far-away candy near boss
						local candies = collectEligibleCandies(bossPart.Position.Y)
						if #candies > 0 then
							local pick = chooseFarthestCandy(candies, bossPart.Position)
							if pick then
								local ok, err = teleportToPart(pick)
								if ok then
									status.Text = "Auto-teleported to candy far from boss."
									attachTouchFlag(pick)
								else
									status.Text = "Auto teleport failed: "..tostring(err)
								end
							else
								status.Text = "No suitable far candy; skipping teleport."
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
			end
		else
			task.wait(0.25)
		end
	end
end)

-- Roll spam loop (spams RollEvent while enabled and boss is within CLOSE_DISTANCE)
task.spawn(function()
	local lastBossPos = nil
	local lastBossCheck = tick()
	local lastAnimId = nil
	local lastSpecialTrigger = 0

	while not stopping and screen.Parent do
		if rollSpamEnabled then
			local boss = workspace:FindFirstChild(BOSS_NAME)
			if boss and boss:IsA("Model") then
				local bossPart = getModelRepresentativePart(boss)
				local char = player.Character
				local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart"))
				if bossPart and hrp then
					local okDist, dist = pcall(function() return (bossPart.Position - hrp.Position).Magnitude end)
					if okDist and dist and dist <= CLOSE_DISTANCE then
						-- measure speed: prefer Velocity magnitude if available, fallback to pos delta
						local speed = 0
						local okVel, velMag = pcall(function() return bossPart.Velocity.Magnitude end)
						if okVel and velMag then
							speed = velMag
						else
							local now = tick()
							local dt = math.max(0.001, now - lastBossCheck)
							local okPos, spd = pcall(function()
								if lastBossPos then
									return (bossPart.Position - lastBossPos).Magnitude / dt
								end
								return 0
							end)
							speed = (okPos and spd) and spd or 0
							lastBossCheck = now
						end
						lastBossPos = bossPart.Position

						-- get playing tracks
						local tracks = {}
						local okTracks, resultTracks = pcall(function() return getAllPlayingTracks(boss) end)
						if okTracks and resultTracks then tracks = resultTracks end

						-- determine if any track is playing; try to extract AnimationId
						local isPlaying = false
						local foundAnimId = nil
						for _,t in ipairs(tracks) do
							local okP, playing = pcall(function() return t.IsPlaying end)
							if okP and playing then
								isPlaying = true
								local okA, animObj = pcall(function() return t.Animation end)
								if okA and animObj and animObj.AnimationId then
									local id = tostring(animObj.AnimationId)
									local digits = id:match("%d+")
									if digits then foundAnimId = digits else foundAnimId = id end
									break
								end
							end
						end

						-- update displayed last animation id if we found one
						if foundAnimId then
							lastAnimId = foundAnimId
						end
						if isPlaying then
							animLabel.Text = ("Current Boss Anim ID: %s"):format(tostring(foundAnimId or lastAnimId or "(playing, id unknown)"))
						else
							animLabel.Text = ("Last Boss Anim ID: %s"):format(tostring(lastAnimId or "N/A"))
						end

						-- SPECIAL: if target anim is playing, do the special pause+single-roll+resume (with cooldown)
						if (foundAnimId == TARGET_ANIM_ID) and (tick() - lastSpecialTrigger >= SPECIAL_COOLDOWN) then
							lastSpecialTrigger = tick()
							local wasEnabled = rollSpamEnabled
							-- stop spamming immediately (only roll spam is affected by this special)
							rollSpamEnabled = false
							status.Text = ("Detected target anim %s — pausing roll spam for %.1fs then firing once..."):format(TARGET_ANIM_ID, SPECIAL_WAIT)
							task.wait(SPECIAL_WAIT)
							pcall(function() fireRoll(boss) end)
							rollSpamEnabled = wasEnabled
							task.wait(0.05)
						else
							-- fallback: original "stopped and animating" behavior (kept)
							if speed <= STOP_SPEED_THRESHOLD and isPlaying then
								status.Text = "Boss stopped & animating — pausing roll spam..."
								task.wait(ROLL_PAUSE_ON_STOP)
							else
								fireRoll(boss)
								task.wait(ROLL_SPAM_INTERVAL)
							end
						end
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

-- Heartbeat updater to keep animLabel responsive
local heartbeatConn = RunService.Heartbeat:Connect(function()
	if not screen.Parent then
		if heartbeatConn and heartbeatConn.Connected then heartbeatConn:Disconnect() end
		return
	end
	local boss = workspace:FindFirstChild(BOSS_NAME)
	if not boss or not boss:IsA("Model") then
		return
	end

	local okTracks, tracks = pcall(function() return getAllPlayingTracks(boss) end)
	if not okTracks or not tracks then return end
	local isPlaying = false
	local foundAnimId = nil
	for _,t in ipairs(tracks) do
		local okP, playing = pcall(function() return t.IsPlaying end)
		if okP and playing then
			isPlaying = true
			local okA, animObj = pcall(function() return t.Animation end)
			if okA and animObj and animObj.AnimationId then
				local id = tostring(animObj.AnimationId)
				local digits = id:match("%d+")
				foundAnimId = digits or id
				break
			end
		end
	end
	if isPlaying then
		animLabel.Text = ("Current Boss Anim ID: %s"):format(tostring(foundAnimId or "(playing, id unknown)"))
	else
		if animLabel.Text == "" or animLabel.Text:match("N/A") then
			animLabel.Text = "Last Boss Anim ID: N/A"
		end
	end
end)

-- Monitor player's humanoid for low-health safety
local function bindCharacter(char)
	-- small delay to let humanoid appear
	local humanoid = char:WaitForChild("Humanoid", 5)
	if humanoid then
		monitorHumanoid(humanoid)
	end
end

-- initial character (if present) and CharacterAdded hook
if player.Character then
	bindCharacter(player.Character)
end
player.CharacterAdded:Connect(function(char) bindCharacter(char) end)

-- cleanup
screen.Destroying:Connect(function()
	stopping = true
	if cameraConn and cameraConn.Connected then cameraConn:Disconnect() end
	if heartbeatConn and heartbeatConn.Connected then heartbeatConn:Disconnect() end
end)
