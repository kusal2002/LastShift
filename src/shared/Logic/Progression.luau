--!strict
-- Player level from total XP. Pure.
-- Going from level L to L+1 costs 100 + 50 * (L - 1) XP.
local Progression = {}

Progression.MaxLevel = 50

function Progression.costToNext(level: number): number
	return 100 + 50 * (level - 1)
end

export type LevelInfo = { level: number, intoLevel: number, toNext: number }

-- toNext is 0 at max level.
function Progression.levelFor(totalXp: number): LevelInfo
	local level = 1
	local remaining = math.max(0, math.floor(totalXp))
	while level < Progression.MaxLevel do
		local cost = Progression.costToNext(level)
		if remaining < cost then
			return { level = level, intoLevel = remaining, toNext = cost }
		end
		remaining -= cost
		level += 1
	end
	return { level = Progression.MaxLevel, intoLevel = 0, toNext = 0 }
end

return Progression
