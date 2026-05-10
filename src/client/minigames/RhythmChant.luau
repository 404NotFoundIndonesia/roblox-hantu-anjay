--!strict
-- RhythmChant — T-37
-- 3-lane DDR-style rhythm mini-game.
-- Config: { notes: { {lane: number, timing: number} }, bpm: number, container: Frame, instanceId: string }
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AudioController = require(script.Parent.Parent.systems.AudioController) :: any

-- ─── State ────────────────────────────────────────────────────────────────────

local RhythmChant = {}

local activeConnections: { RBXScriptConnection } = {}
local activeInstances: { Instance } = {}
local running = false
local onInputFn: (({ [string]: any }) -> any)? = nil
local gameStartTime = 0.0

type NoteData = { lane: number, timing: number, frame: Frame?, hit: boolean }
local noteData: { NoteData } = {}

-- UI refs
local laneFrames: { Frame } = {}

-- ─── Constants ────────────────────────────────────────────────────────────────

local LANE_WIDTH = 90
local LANE_HEIGHT = 400
local NOTE_HEIGHT = 30
local HIT_ZONE_Y = LANE_HEIGHT - 60 -- pixel offset from lane top where hit zone starts
local NOTE_SPEED = 300 -- pixels per second
local HIT_WINDOW = 0.15 -- seconds
local MISS_CLEANUP_OFFSET = 60 -- pixels below hit zone before note is culled

local LANE_COLORS = {
	Color3.fromRGB(80, 140, 220),
	Color3.fromRGB(220, 120, 60),
	Color3.fromRGB(80, 200, 120),
}
local C_BG = Color3.fromRGB(15, 15, 28)
local C_HIT_ZONE = Color3.fromRGB(255, 255, 255)
local C_NOTE = Color3.fromRGB(240, 240, 100)
local C_TEXT = Color3.fromRGB(230, 230, 230)
local LANE_KEY_LABELS = { "Q", "W", "E" }

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function addCorner(parent: Instance, r: number)
	local c = Instance.new("UICorner") :: UICorner
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function track(inst: Instance)
	table.insert(activeInstances, inst)
end

local function playHitSound()
	pcall(function()
		if type(AudioController.playUI) == "function" then
			(AudioController.playUI :: (string) -> ())("minigame_hit")
		end
	end)
end

-- ─── Note frame creation ──────────────────────────────────────────────────────

local function spawnNoteFrame(laneFrame: Frame, note: NoteData)
	local f = Instance.new("Frame") :: Frame
	f.Name = "Note"
	f.Size = UDim2.new(1, -8, 0, NOTE_HEIGHT)
	f.Position = UDim2.fromOffset(4, -NOTE_HEIGHT)
	f.BackgroundColor3 = C_NOTE
	f.ZIndex = 3
	f.Parent = laneFrame
	addCorner(f, 4)
	note.frame = f
end

-- ─── Hit detection ────────────────────────────────────────────────────────────

local function findNoteInWindow(lane: number): NoteData?
	local elapsed = os.clock() - gameStartTime
	local best: NoteData? = nil
	local bestDelta = math.huge
	for _, note in noteData do
		if note.lane ~= lane then
			continue
		end
		if note.hit then
			continue
		end
		local delta = math.abs(elapsed - note.timing)
		if delta <= HIT_WINDOW and delta < bestDelta then
			best = note
			bestDelta = delta
		end
	end
	return best
end

local function handleLaneTap(lane: number)
	if not running then
		return
	end
	local elapsed = os.clock() - gameStartTime
	local note = findNoteInWindow(lane)

	if note ~= nil then
		note.hit = true
		playHitSound()
		if note.frame ~= nil then
			note.frame.BackgroundColor3 = Color3.fromRGB(100, 240, 100)
		end
		local hitDelta = elapsed - note.timing
		if onInputFn ~= nil then
			local fn = onInputFn :: ({ [string]: any }) -> any
			task.spawn(function()
				fn({ lane = lane, hitDelta = hitDelta })
			end)
		end
	end
end

-- ─── Build UI ─────────────────────────────────────────────────────────────────

local function buildUI(container: Frame, notes: { NoteData })
	local root = Instance.new("Frame") :: Frame
	root.Name = "RhythmChantRoot"
	root.Size = UDim2.fromOffset(LANE_WIDTH * 3 + 48, LANE_HEIGHT + 100)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.BackgroundColor3 = C_BG
	root.BackgroundTransparency = 0.05
	root.Parent = container
	addCorner(root, 10)
	track(root)

	-- Title
	local title = Instance.new("TextLabel") :: TextLabel
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Position = UDim2.fromScale(0, 0)
	title.BackgroundTransparency = 1
	title.TextColor3 = C_TEXT
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Text = "Irama Mantra"
	title.Parent = root

	-- Lane container
	local laneContainer = Instance.new("Frame") :: Frame
	laneContainer.Name = "Lanes"
	laneContainer.Size = UDim2.fromOffset(LANE_WIDTH * 3 + 24, LANE_HEIGHT)
	laneContainer.Position = UDim2.fromOffset(12, 40)
	laneContainer.BackgroundTransparency = 1
	laneContainer.Parent = root

	local laneLayout = Instance.new("UIListLayout") :: UIListLayout
	laneLayout.FillDirection = Enum.FillDirection.Horizontal
	laneLayout.Padding = UDim.new(0, 6)
	laneLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	laneLayout.Parent = laneContainer

	for i = 1, 3 do
		local lane = Instance.new("Frame") :: Frame
		lane.Name = "Lane" .. tostring(i)
		lane.Size = UDim2.fromOffset(LANE_WIDTH, LANE_HEIGHT)
		lane.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
		lane.ClipsDescendants = true
		lane.ZIndex = 1
		lane.Parent = laneContainer
		addCorner(lane, 6)

		-- Lane color side strip
		local strip = Instance.new("Frame") :: Frame
		strip.Name = "Strip"
		strip.Size = UDim2.new(0, 4, 1, 0)
		strip.BackgroundColor3 = LANE_COLORS[i]
		strip.ZIndex = 2
		strip.Parent = lane

		-- Hit zone indicator
		local hitZone = Instance.new("Frame") :: Frame
		hitZone.Name = "HitZone"
		hitZone.Size = UDim2.new(1, -8, 0, NOTE_HEIGHT)
		hitZone.Position = UDim2.fromOffset(4, HIT_ZONE_Y)
		hitZone.BackgroundColor3 = C_HIT_ZONE
		hitZone.BackgroundTransparency = 0.75
		hitZone.ZIndex = 2
		hitZone.Parent = lane
		addCorner(hitZone, 4)

		laneFrames[i] = lane

		_ = strip
		_ = hitZone
	end

	-- Tap buttons row (below lanes, for mobile)
	local btnRow = Instance.new("Frame") :: Frame
	btnRow.Name = "BtnRow"
	btnRow.Size = UDim2.fromOffset(LANE_WIDTH * 3 + 24, 56)
	btnRow.Position = UDim2.fromOffset(12, LANE_HEIGHT + 44)
	btnRow.BackgroundTransparency = 1
	btnRow.Parent = root

	local btnLayout = Instance.new("UIListLayout") :: UIListLayout
	btnLayout.FillDirection = Enum.FillDirection.Horizontal
	btnLayout.Padding = UDim.new(0, 6)
	btnLayout.Parent = btnRow

	for i = 1, 3 do
		local capturedLane = i
		local btn = Instance.new("TextButton") :: TextButton
		btn.Name = "TapBtn" .. tostring(i)
		btn.Size = UDim2.fromOffset(LANE_WIDTH, 52)
		btn.BackgroundColor3 = LANE_COLORS[i]
		btn.BackgroundTransparency = 0.3
		btn.TextColor3 = C_TEXT
		btn.Font = Enum.Font.GothamBold
		btn.TextScaled = true
		btn.Text = LANE_KEY_LABELS[i]
		btn.AutoButtonColor = true
		btn.Parent = btnRow
		addCorner(btn, 8)
		btn.Activated:Connect(function()
			handleLaneTap(capturedLane)
		end)
		_ = btn
	end

	-- Spawn note frames for all notes
	for _, note in notes do
		local laneFrame = laneFrames[note.lane]
		if laneFrame ~= nil then
			spawnNoteFrame(laneFrame, note)
		end
	end

	_ = title
	_ = laneLayout
	_ = btnLayout
	_ = laneContainer
end

-- ─── Keyboard wiring ──────────────────────────────────────────────────────────

local LANE_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.Q] = 1,
	[Enum.KeyCode.W] = 2,
	[Enum.KeyCode.E] = 3,
	[Enum.KeyCode.ButtonX] = 1,
	[Enum.KeyCode.ButtonA] = 2,
	[Enum.KeyCode.ButtonB] = 3,
}

local function wireKeyboard()
	local conn = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if not running then
			return
		end
		local lane = LANE_KEYS[input.KeyCode]
		if lane ~= nil then
			handleLaneTap(lane)
		end
	end)
	table.insert(activeConnections, conn)
end

-- ─── Scroll loop ──────────────────────────────────────────────────────────────

local function startScrollLoop()
	local scrollConn = RunService.Heartbeat:Connect(function()
		if not running then
			return
		end
		local elapsed = os.clock() - gameStartTime
		for _, note in noteData do
			local frame = note.frame
			if frame == nil then
				continue
			end
			-- Pixel Y from top of lane: note arrives at HIT_ZONE_Y when elapsed == timing
			local yOffset = HIT_ZONE_Y - (note.timing - elapsed) * NOTE_SPEED
			if yOffset > LANE_HEIGHT + MISS_CLEANUP_OFFSET or yOffset < -NOTE_HEIGHT then
				frame.Visible = false
			else
				frame.Visible = true
				frame.Position = UDim2.fromOffset(4, yOffset)
			end
		end
	end)
	table.insert(activeConnections, scrollConn)
end

-- ─── Public interface ─────────────────────────────────────────────────────────

function RhythmChant.start(config: { [string]: any }, onInput: ({ [string]: any }) -> any)
	running = true
	onInputFn = onInput
	gameStartTime = os.clock()
	laneFrames = {}

	local rawNotes = config.notes :: { { lane: number, timing: number } }
	noteData = {}
	for _, n in rawNotes do
		table.insert(noteData, { lane = n.lane, timing = n.timing, frame = nil, hit = false })
	end

	buildUI(config.container :: Frame, noteData)
	wireKeyboard()
	startScrollLoop()

	_ = config.bpm
end

function RhythmChant.stop()
	running = false
	onInputFn = nil
	for _, conn in activeConnections do
		conn:Disconnect()
	end
	activeConnections = {}
	for _, inst in activeInstances do
		if inst.Parent ~= nil then
			inst:Destroy()
		end
	end
	activeInstances = {}
	noteData = {}
	laneFrames = {}
end

return RhythmChant
