--!strict
-- CompanionController — T-45
-- Client-local companion ghost: the player's rarest captured ghost follows them.
-- Other players do not see the companion (model parented to workspace but never replicated
-- because it is created client-side via a LocalScript context).
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local LocalPlayer = Players.LocalPlayer

-- ─── Module ───────────────────────────────────────────────────────────────────

local CompanionController = {}

-- ─── State ────────────────────────────────────────────────────────────────────

local companionModel: Model? = nil
local followConn: RBXScriptConnection? = nil

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function despawnCompanion()
	if followConn ~= nil then
		followConn:Disconnect()
		followConn = nil
	end
	if companionModel ~= nil then
		companionModel:Destroy()
		companionModel = nil
	end
end

local function spawnCompanion(ghostId: string)
	despawnCompanion()

	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets") :: Folder?
	if assetsFolder == nil then
		return
	end
	local ghostsFolder = assetsFolder:FindFirstChild("Ghosts") :: Folder?
	if ghostsFolder == nil then
		return
	end
	local template = ghostsFolder:FindFirstChild(ghostId) :: Model?
	if template == nil then
		return
	end

	local model = (template :: Model):Clone()
	model:ScaleTo(0.4)

	-- Disable all physics interaction so companion never blocks gameplay.
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			local part = desc :: BasePart
			part.CanCollide = false
			part.CanTouch = false
			part.Anchored = false
			part.Massless = true
		end
	end

	model.Parent = workspace
	companionModel = model

	-- Heartbeat lerp — smooth follow without rubber-banding.
	followConn = RunService.Heartbeat:Connect(function()
		if model.Parent == nil then
			despawnCompanion()
			return
		end
		local root = model.PrimaryPart
		if root == nil then
			return
		end
		local char = LocalPlayer.Character
		if char == nil then
			return
		end
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp == nil then
			return
		end
		-- Target offset: 3 studs behind, 1 stud to the right of HumanoidRootPart.
		local targetCF = hrp.CFrame * CFrame.new(1, 0, 3)
		model:PivotTo(root.CFrame:Lerp(targetCF, 0.1))
	end)
end

-- ─── Init ─────────────────────────────────────────────────────────────────────

function CompanionController.Init()
	;(Remotes["CompanionSet"] :: RemoteEvent).OnClientEvent:Connect(function(
		payload: { ghostId: string? }
	)
		local ghostId = payload.ghostId
		if ghostId == nil then
			despawnCompanion()
			return
		end
		spawnCompanion(ghostId :: string)
	end)
end

return CompanionController
