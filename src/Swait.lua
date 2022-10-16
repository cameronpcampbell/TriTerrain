-- A Stressed Version Of "task.wait()".
local lastTick = tick()
local lastTime = 1
local stress = 8
return function()
	local tic2 = tick()
	local tim = tic2-lastTick
	if (tim/stress)<=lastTime then
		lastTime = tim
		lastTick = tic2
		return true
	end
	lastTime = tim
	lastTick = tic2
	task.wait()
	return true
end
