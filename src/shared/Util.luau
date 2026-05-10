--!strict

local Util = {}

-- Picks a key from a weights table using weighted random selection.
-- Weights are relative (e.g. {A=60, B=30, C=10} → A is 6× more likely than C).
-- Returns an arbitrary key on an empty table (should not happen in practice).
function Util.weightedRandom(weights: { [string]: number }): string
	local total = 0
	for _, w in weights do
		total += w
	end

	assert(total > 0, "Util.weightedRandom: total weight must be > 0")

	local roll = math.random() * total
	local cumulative = 0
	for key, w in weights do
		cumulative += w
		if roll <= cumulative then
			return key
		end
	end

	-- Floating-point edge case: return the last key
	local lastKey = ""
	for key in weights do
		lastKey = key
	end
	return lastKey
end

-- Returns true only when pos is strictly inside the AABB bounds (exclusive boundaries).
-- Returns false when pos is exactly on a boundary plane or outside.
function Util.isInsideBounds(
	pos: Vector3,
	bounds: { min: Vector3, max: Vector3 }
): boolean
	return pos.X > bounds.min.X
		and pos.X < bounds.max.X
		and pos.Y > bounds.min.Y
		and pos.Y < bounds.max.Y
		and pos.Z > bounds.min.Z
		and pos.Z < bounds.max.Z
end

-- Counts the number of non-nil entries in a dictionary table.
-- Works for both array-style and hash-style tables.
function Util.countTable(t: { [string]: any }): number
	local count = 0
	for _ in t do
		count += 1
	end
	return count
end

-- Formats a Unix timestamp (os.time()) as "DD/MM/YYYY".
-- Falls back to a numeric string if os.date is unavailable.
function Util.formatDate(timestamp: number): string
	local ok, result = pcall(function()
		return os.date("%d/%m/%Y", timestamp)
	end)
	if ok and type(result) == "string" then
		return result
	end
	return tostring(timestamp)
end

return Util
