-- Single-file LocalScript
-- Creates a GUI that teleports the player to any object whose name contains "candy corn"
-- Place in StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")

-- CONFIG
local SEARCH_TERM = "candy corn" -- substring to look for (case-insensitive)
local AUTO_INTERVAL = 0.6        -- seconds between auto-teleports when toggled on
local TELEPORT_OFFSET = Vector3.new(0, 3, 0) -- offset from target position to place player's root part

-- cleanup old
local old = gui:FindFirstChild("CandyCornTeleporter")
if old then old:Destroy() end

-- UI
local screen = Instance.new("ScreenGui", gui)
screen.Name = "CandyCornTeleporter"
screen.ResetOnSpawn = false

local frame = Instance.new("Frame", screen)
frame.Size = UDim2.new(0, 260, 0, 120)
frame.Position = UDim2.new(0, 12, 0, 60)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Name = "MainFrame"
frame.ClipsDescendants = true

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, -8, 0, 28)
title.Position = UDim2.new(0, 4, 0, 4)
title.BackgroundTransparency = 1
title.Font = Enum.Font.SourceSansSemibold
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(235,235,235)
title.Text = "CandyCorn Teleporter"

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
status.Text = "Searching for matches..."

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

-- helper: find candidate parts to teleport to
local function collectTargets(term)
	term = term:lower()
	local parts = {}
	-- search models and parts in workspace
	for _, obj in ipairs(workspace:GetDescendants()) do
		-- if the object itself is a BasePart and its name matches
		if obj:IsA("BasePart") then
			if obj.Name:lower():find(term, 1, true) then
				table.insert(parts, obj)
			end
		-- if it's a Model and its name matches, try to get a useful part
		elseif obj:IsA("Model") then
			if obj.Name:lower():find(term, 1, true) then
				local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
				if p then table.insert(parts, p) end
			end
		end
	end
	return parts
end

-- helper: get nearest target part to player's HumanoidRootPart
local function getNearestTarget(parts)
	if not parts or #parts == 0 then return nil end
	local char = player.Character
	if not char then return parts[1] end
	local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
	if not hrp then return parts[1] end
	local best, bestDist
	for _, p in ipairs(parts) do
		if p and p:IsDescendantOf(workspace) then
			local ok, dist = pcall(function() return (p.Position - hrp.Position).Magnitude end)
			if ok then
				if not bestDist or dist < bestDist then
					bestDist = dist
					best = p
				end
			end
		end
	end
	return best
end

-- teleport function (safe-ish)
local function teleportToPart(part)
	if not part or not part:IsDescendantOf(workspace) then return false, "no target" end
	local char = player.Character
	if not char then return false, "no character" end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false, "no HRP" end
	local targetCFrame
	local ok, err = pcall(function()
		targetCFrame = part.CFrame + TELEPORT_OFFSET
	end)
	if not ok then return false, err end
	local ok2, err2 = pcall(function()
		hrp.CFrame = targetCFrame
	end)
	return ok2, err2
end

-- UI state and loop
local auto = false
local stopping = false

toggleBtn.MouseButton1Click:Connect(function()
	auto = not auto
	toggleBtn.Text = auto and "Auto: ON" or "Auto: OFF"
end)

nowBtn.MouseButton1Click:Connect(function()
	local parts = collectTargets(SEARCH_TERM)
	status.Text = ("Found %d match(es)."):format(#parts)
	local target = getNearestTarget(parts)
	if not target then
		status.Text = "No valid target found."
		return
	end
	local ok, err = teleportToPart(target)
	if ok then status.Text = "Teleported now." else status.Text = "Teleport failed: "..tostring(err) end
end)

-- auto loop (non-blocking)
task.spawn(function()
	while not stopping and screen.Parent do
		if auto then
			local parts = collectTargets(SEARCH_TERM)
			status.Text = ("Found %d match(es). Auto teleporting..."):format(#parts)
			local target = getNearestTarget(parts)
			if target then
				local ok, err = teleportToPart(target)
				if not ok then
					status.Text = "Auto teleport failed: "..tostring(err)
				end
			else
				status.Text = "No target found."
			end
			task.wait(AUTO_INTERVAL)
		else
			-- when auto is off, keep status updated occasionally
			local parts = collectTargets(SEARCH_TERM)
			status.Text = ("Found %d match(es)."):format(#parts)
			task.wait(1)
		end
	end
end)

-- cleanup on destroy
screen.Destroying:Connect(function() stopping = true end)
