--!strict

-- XPTable[level] = cumulative XP required to reach that level from level 1.
-- Formula for per-level XP cost: math.floor(100 * (1.3 ^ (level - 2)))
-- Cumulative values are summed from level 2 upward.
--
-- Spot-check:
--   XPTable[2] = 100
--   XPTable[3] = 100 + 130 = 230
--   XPTable[4] = 230 + 169 = 399   (~400 per PRD)
--   XPTable[5] = 399 + 219 = 618   (~620 per PRD)

local XPTable: { [number]: number } = {}

local cumulative = 0
for level = 2, 100 do
	local cost = math.floor(100 * (1.3 ^ (level - 2)))
	cumulative += cost
	XPTable[level] = cumulative
end

return XPTable
