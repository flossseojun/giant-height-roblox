-- 펫 목록 다루기 (구역 키를 넘으면 해금)
local Pets = {}

export type Pet = { id: string, name: string, minHeight: number, mult: number, radius: number }

function Pets.isUnlocked(pet: Pet, height: number): boolean
	return height >= pet.minHeight
end

function Pets.find(list: { Pet }, id: any): Pet?
	for _, p in list do
		if p.id == id then
			return p
		end
	end
	return nil
end

function Pets.bestUnlocked(list: { Pet }, height: number): Pet
	local best = list[1]
	for _, p in list do
		if Pets.isUnlocked(p, height) and p.mult > best.mult then
			best = p
		end
	end
	return best
end

return Pets
