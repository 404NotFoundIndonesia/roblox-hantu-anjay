--!strict

-- Remotes.luau
-- Creates all RemoteEvents and RemoteFunctions on the server on first require.
-- On the client, waits for them to exist (created by server init).
-- All systems access remotes through this module — no scattered WaitForChild calls.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IS_SERVER = RunService:IsServer()
local WAIT_TIMEOUT = 15 -- seconds client waits before erroring

-- Names of all RemoteEvents (server → client, one-way)
local REMOTE_EVENT_NAMES: { string } = {
	"GhostSpawned",
	"GhostDespawned",
	"GhostStateChanged",
	"ScanPulseResult",
	"MiniGameStart",
	"MiniGameEnd",
	"CompendiumUpdated",
	"XPUpdated",
	"ShardsUpdated",
	"BottlesUpdated",
	"QuestProgress",
	"QuestCompleted",
	"LevelUp",
	"ZoneChanged",
	"TutorialStep",
	"CompanionSet",
}

-- Names of all RemoteFunctions (client → server, awaits response)
local REMOTE_FUNCTION_NAMES: { string } = {
	"RequestScan",
	"RequestCapture",
	"RequestMiniGameInput",
	"RequestPurchaseShard",
	"RequestEquipBottle",
	"RequestViewCompendium",
	"RequestSkipTutorial",
	"RequestBuyBottle", -- added per PRD §14.2
}

-- Get or create the Remotes folder in ReplicatedStorage
local remotesFolder: Folder

if IS_SERVER then
	-- Server: create folder once (module is cached, so this runs exactly once)
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing and existing:IsA("Folder") then
		remotesFolder = existing
	else
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage
	end
else
	-- Client: wait for server to create the folder
	local found = ReplicatedStorage:WaitForChild("Remotes", WAIT_TIMEOUT)
	assert(found ~= nil, "[Remotes] Timed out waiting for Remotes folder after " .. WAIT_TIMEOUT .. "s")
	remotesFolder = found :: Folder
end

-- Populate the Remotes dictionary
local Remotes: { [string]: RemoteEvent | RemoteFunction } = {}

-- RemoteEvents
for _, name in REMOTE_EVENT_NAMES do
	if IS_SERVER then
		local existing = remotesFolder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			Remotes[name] = existing
		else
			local re = Instance.new("RemoteEvent")
			re.Name = name
			re.Parent = remotesFolder
			Remotes[name] = re
		end
	else
		local found = remotesFolder:WaitForChild(name, WAIT_TIMEOUT)
		assert(
			found ~= nil,
			"[Remotes] Timed out waiting for RemoteEvent '" .. name .. "' after " .. WAIT_TIMEOUT .. "s"
		)
		Remotes[name] = found :: RemoteEvent
	end
end

-- RemoteFunctions
for _, name in REMOTE_FUNCTION_NAMES do
	if IS_SERVER then
		local existing = remotesFolder:FindFirstChild(name)
		if existing and existing:IsA("RemoteFunction") then
			Remotes[name] = existing
		else
			local rf = Instance.new("RemoteFunction")
			rf.Name = name
			rf.Parent = remotesFolder
			Remotes[name] = rf
		end
	else
		local found = remotesFolder:WaitForChild(name, WAIT_TIMEOUT)
		assert(
			found ~= nil,
			"[Remotes] Timed out waiting for RemoteFunction '" .. name .. "' after " .. WAIT_TIMEOUT .. "s"
		)
		Remotes[name] = found :: RemoteFunction
	end
end

return Remotes
