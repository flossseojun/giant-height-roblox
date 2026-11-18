-- 키에 따른 칭호
local Titles = {}

export type Title = { minHeight: number, name: string, announce: boolean? }

function Titles.forHeight(height: number, list: { Title }): Title
	local best = list[1]
	for _, t in list do
		if height >= t.minHeight and t.minHeight >= best.minHeight then
			best = t
		end
	end
	return best
end

-- 칭호가 바뀌었으면 새 칭호, 아니면 nil
function Titles.crossed(old: number, new: number, list: { Title }): Title?
	local a = Titles.forHeight(old, list)
	local b = Titles.forHeight(new, list)
	if a.name ~= b.name then
		return b
	end
	return nil
end

return Titles
