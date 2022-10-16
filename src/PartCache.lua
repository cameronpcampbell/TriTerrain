local PartCache = {}
local CacheInsts = {}; CacheInsts.__index = CacheInsts

local CF_REALLY_FAR_AWAY = CFrame.new(0, 100000000, 0)

function PartCache.new(inst, amount, parent)
	local created = table.create(amount)
	for count = 1,amount do
		local cloned = inst:Clone()
		cloned:PivotTo(CF_REALLY_FAR_AWAY)
		cloned.Parent = workspace
		table.insert(created, cloned)
	end
	
	return setmetatable({t_available=created, t_inUse={}}, CacheInsts)
end

function CacheInsts:take()
	local part = self.t_available[#self.t_available]
	self.t_available[#self.t_available] = nil
	table.insert(self.t_inUse, part)
	return part
end

function CacheInsts:putBack(part)
	local index = table.find(self.t_inUse, part)
	if not index then return warn("This instance is not part of this cache!") end
	table.remove(self.t_inUse, index)
	table.insert(self.t_available, part)
	part:PivotTo(CF_REALLY_FAR_AWAY)
end

return PartCache
