-- Requires Stressed Wait.
local Swait = require(script.Parent.Swait)

-- Creates A 2D Grid With A Set Amount Of Rows And Columns.
local function createGrid(rows, cols)
	local grid = {}
	for i = 1, rows do
		grid[i] = {}

		for j = 1, cols do
			grid[i][j] = 0
		end
	end

	return grid
end

-- Checks To If A Point Intersects The Radius Of Another Point.
local function isValid(candidate, rows,cols, region, cellSize, radius, points, grid)
	if candidate.X >=0 and candidate.X < region.X and candidate.Y >=0 and candidate.Y < region.Y then
		local cellX = math.floor(candidate.X/cellSize)
		local cellY = math.floor(candidate.Y/cellSize)
		local searchStartX = math.max(0, cellX -2)
		local searchEndX = math.min(cellX+2, rows-1)
		local searchStartY = math.max(0, cellY -2)
		local searchEndY = math.min(cellY+2, cols-1)

		for x = searchStartX, searchEndX do
			for y = searchStartY, searchEndY do
				local pointIndex = grid[x+1][y+1]-1
				if pointIndex ~= -1 then
					local dst = (candidate - points[pointIndex+1]).Magnitude
					if dst < radius then
						return false
					end
				end
			end
		end
		return true
	end
	return false
end

-- The Poisson Disc Algorithm
return function(radius, region, samples, random)
	local cellSize = radius/math.sqrt(2)

	local rows, cols = math.ceil(region.X/cellSize), math.ceil(region.Y/cellSize)
	local grid = createGrid(rows, cols)
	local points = {}
	local spawnPoints = {}

	table.insert(spawnPoints, region/2)
	while #spawnPoints > 0 do
		local spawnIndex = random:NextInteger(1, #spawnPoints)
		local spawnCentre = spawnPoints[spawnIndex]
		local candidateAccepted = false

		for count = 1, samples do
			local angle = random:NextNumber() * math.pi * 2
			local dir = Vector2.new(math.sin(angle), math.cos(angle))
			local candidate = spawnCentre + dir * random:NextInteger(radius, 2*radius)

			if isValid(candidate, rows,cols, region, cellSize, radius, points, grid) then
				table.insert(points, candidate)
				table.insert(spawnPoints, candidate)
				grid[math.ceil(candidate.X/cellSize)][math.ceil(candidate.Y/cellSize)] = #points
				candidateAccepted = true
				break
			end

		end
		Swait()

		if not candidateAccepted then
			table.remove(spawnPoints, spawnIndex)
		end
	end

	return points
end
