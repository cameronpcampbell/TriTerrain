local PartTerrain = {}
local Chunk = {}; Chunk.__index = Chunk

-- Settings.
local Settings = require(script.Parent.Settings)
local WIDTH, HEIGHT, DEPTH, SCALE = Settings.WIDTH, Settings.HEIGHT, Settings.DEPTH, Settings.SCALE
local SEED, ISOVALUE, SMOOTH = Settings.SEED, Settings.ISOVALUE, Settings.SMOOTH

-- Tables For The Marching Cubes Algorithm.
local TRIANGULATION_TABLE = require(script.Parent.TriangulationTable)
local MIDPOINTS = {
	{0,1}, {1,2}, {2,3}, {3,0},
	{4,5}, {5,6}, {6,7}, {7,4},
	{0,4}, {1,5}, {2,6}, {3,7}
}
local OFFSETS = {
	Vector3.new(SCALE, 0, 0),
	Vector3.new(SCALE, 0, SCALE),
	Vector3.new(0, 0, SCALE),

	Vector3.new(0, SCALE, 0),
	Vector3.new(SCALE, SCALE, 0),
	Vector3.new(SCALE, SCALE, SCALE),
	Vector3.new(0, SCALE, SCALE),
}

-- Variables For Poisson Disc Sampling.
local PoissonDiscSampling = require(script.Parent.PoissonDiscSampling)
local castParams = RaycastParams.new()
castParams.CollisionGroup = "PlacementRays"

-- Variables For The Terrain Data.
local positions = {}
local toMarch = {}
local colors = {}

-- Variables For The Terrain Instances.
local PartCache = require(script.Parent.PartCache)
local TerrainCache = nil
local Triangle = script.Parent.Triangle
local Trees = script.Parent.Trees:GetChildren()

-- Color Variables.
local grassColor = Color3.fromRGB(155, 191, 75)
local dirtColor = Color3.fromRGB(120, 72, 31)
local stoneColor = Color3.fromRGB(121, 120, 124)

-- Requires Stressed Wait.
local Swait = require(script.Parent.Swait)

-- [ HELPER FUNCTIONS ] ==========================================================================
-- Shoots A Ray Down Onto The Surface.
local function raycastToSurface(pos)
	local rayOrigin = pos + Vector3.new(0, 50, 0)
	local rayDirection = Vector3.new(0, -100, 0)

	local raycastResult = workspace:Raycast(rayOrigin, rayDirection, castParams)
	if not raycastResult then return pos end
	local position = raycastResult.Position
	local rotation = raycastResult.Instance.CFrame.Rotation

	if raycastResult.Instance.Color ~= grassColor then return end

	return position, rotation
end

-- Chooses The Color For A Tri.
function chooseTriColor(...)
	local t = {...}
	
	if table.find(t, grassColor) then return grassColor end
	if table.find(t, stoneColor) then return stoneColor end
	return dirtColor
end

-- Creates a 3D Triangle Using 3 Positions.
local function Draw3DTri(A, B, C, cacheTri, t_terrainParts, t_cframes, color)
	local AB, AC, BC = B-A, C-A, C-B
	local ABD, ACD, BCD = AB.Magnitude, AC.Magnitude, BC.Magnitude

	if ABD > ACD and ABD > BCD then
		C, A = A, C
	elseif ACD > BCD and ACD > ABD then
		A, B = B, A
	end

	AB, AC, BC = B-A, C-A, C-B

	local Right, Back = AC:Cross(AB).Unit, BC.Unit
	local Up = BC:Cross(Right).Unit
	local Height = math.abs(AB:Dot(Up))

	cacheTri.W1.Size = Vector3.new(0, Height, math.abs(AB:Dot(Back)))
	local W1CFrame = CFrame.fromMatrix((A+B)*.5, Right, Up, Back) --[[* CFAngles(0, MathRad(180), 0)]]

	cacheTri.W2.Size = Vector3.new(0, Height, math.abs(AC:Dot(Back)))
	local W2CFrame = CFrame.fromMatrix((A+C)*.5, -Right, Up, -Back) --[[* CFAngles(0, MathRad(180), 0)]]

	table.insert(t_terrainParts, cacheTri.W1); table.insert(t_terrainParts, cacheTri.W2)
	table.insert(t_cframes, W1CFrame); table.insert(t_cframes, W2CFrame)

	cacheTri.W1.Color = color; cacheTri.W2.Color = color

	return cacheTri
end

-- Layered Noise.
local function FractalNoise(x, y, z, octaves, lacunarity, persistence, scale)
	local value = 0 
	local x1 = x 
	local y1 = y
	local z1 = z
	local amplitude = 1
	for i = 1, octaves, 1 do
		value += math.noise(x1 / scale, y1 / scale, z1 / scale) * amplitude
		y1 *= lacunarity
		x1 *= lacunarity
		z1 *= lacunarity
		amplitude *= persistence
	end

	return value
end

-- Interpolates Between 2 Positions Using 2 Values.
function Interpolate(pos1, pos2)
	if not SMOOTH then return (pos1 + pos2)/2 end

	local val1 = positions[pos1]
	local val2 = positions[pos2]

	local interpolatedPos = pos1+((ISOVALUE-val1)/(val2-val1))*(pos2-pos1)

	return interpolatedPos
end

-- Performs The Marching Cubes Algorithm From A Starting Position.
function March(startPos, t_parts, t_cframes)
	
	-- Gets The Positions Of The Cube We Are Dealing With.
	local currPositions = {
		startPos, startPos+OFFSETS[1], startPos+OFFSETS[2], startPos+OFFSETS[3],
		startPos+OFFSETS[4], startPos+OFFSETS[5], startPos+OFFSETS[6], startPos+OFFSETS[7]
	}
	
	-- Calculates The Index Of The Cube In The Triangulation Table.
	local index = (positions[startPos] < ISOVALUE and 0 or 1)
		+(positions[startPos+OFFSETS[1]] < ISOVALUE and 0 or 2)
		+(positions[startPos+OFFSETS[2]] < ISOVALUE and 0 or 4)
		+(positions[startPos+OFFSETS[3]] < ISOVALUE and 0 or 8)
		+(positions[startPos+OFFSETS[4]] < ISOVALUE and 0 or 16)
		+(positions[startPos+OFFSETS[5]] < ISOVALUE and 0 or 32)
		+(positions[startPos+OFFSETS[6]] < ISOVALUE and 0 or 64)
		+(positions[startPos+OFFSETS[7]] < ISOVALUE and 0 or 128)
	index = TRIANGULATION_TABLE[index+1]
	if index == 0 or index == 256 then return end
	
	for count=1,#index/3 do
		-- Gets The Indexes For The Algorithm.
		local index1 = MIDPOINTS[index[(1-3)+(3*count)]+1]
		local index2 = MIDPOINTS[index[(2-3)+(3*count)]+1]
		local index3 = MIDPOINTS[index[(3-3)+(3*count)]+1]

		if index1 == nil or index2 == nil or index3 == nil then continue end
		
		-- Gets The Positions For The Algorithm.
		local positions1 = {currPositions[index1[1]+1],currPositions[index1[2]+1]}
		local positions2 = {currPositions[index2[1]+1],currPositions[index2[2]+1]}
		local positions3 = {currPositions[index3[1]+1],currPositions[index3[2]+1]}
		
		-- Creates The Triangle From The Positions.
		Draw3DTri(
			Interpolate(positions1[1], positions1[2]),
			Interpolate(positions2[1], positions2[2]),
			Interpolate(positions3[1], positions3[2]),
			
			TerrainCache:take(),
			t_parts,
			t_cframes,
			chooseTriColor(
				colors[positions1[1]], colors[positions1[2]],
				colors[positions2[1]], colors[positions2[2]],
				colors[positions3[1]], colors[positions3[2]]
			)
		)
		
		Swait()	
	end
end
-- ===============================================================================================

-- Inits The Part Pool For The Wedges (Tris).
function PartTerrain.init(tris)
	TerrainCache = PartCache.new(Triangle, tris, workspace.Terrain)
	return TerrainCache
end

-- Creates The Chunk Data.
function PartTerrain.new(xOffset,yOffset,zOffset)
	local localX, localY, localZ = xOffset,yOffset,zOffset
	xOffset *= WIDTH*SCALE; yOffset *= DEPTH*SCALE; zOffset *= DEPTH*SCALE
	
	for x=xOffset,(WIDTH*SCALE)+xOffset,SCALE do
		for z=zOffset,(DEPTH*SCALE)+zOffset,SCALE do
			for y=yOffset,(HEIGHT*SCALE)+yOffset,SCALE do
				local position = Vector3.new(x,y,z)
				
				if not positions[position] then
					positions[position] = FractalNoise(x, z, SEED,
						8,  -- Octaves.
						10, -- Lacunarity.
						0,  -- Persistence.
						200 -- Scale.
					) +(y*0.02)-ISOVALUE
					
					-- If Below The Surface.
					if positions[position] < ISOVALUE then
						local caveValue = FractalNoise(x, y, z,
							8,  -- Octaves
							10, -- Lacunarity
							0,  -- Persistence
							20  -- Scale
						)
						
						-- If Below Dirt Level (Stone Color).
						if positions[position] < -0.6 then
							colors[position] = stoneColor
						-- if Below Grass Level (Dirt Color).
						else
							colors[position] = dirtColor
						end
						
						-- If Should Replace Surface Terrain With Cave Terrain.
						if caveValue > positions[position] then
							positions[position] = caveValue
						end
						
					-- If On The Surface (Grass Color).
					else
						colors[position] = grassColor
					end
					
				end
	
			end
		end
		Swait()
	end
	
	return setmetatable({
		localPos = Vector3.new(localX, localY, localZ),
		worldPos = Vector3.new(xOffset, yOffset, zOffset),
	}, Chunk)
end

-- Generates The Chunk Using The Marching Cubes Algorithm.
function Chunk:gen()
	local xOffset, yOffset, zOffset = self.worldPos.X, self.worldPos.Y, self.worldPos.Z
	local t_parts, t_cframes = {}, {}
	
	for x=xOffset,(WIDTH*SCALE)+xOffset,SCALE do
		if x > ((WIDTH*SCALE)+xOffset)-SCALE then continue end
		
		for z=zOffset,(DEPTH*SCALE)+zOffset,SCALE do
			if z > ((DEPTH*SCALE)+zOffset)-SCALE then continue end
			
			for y=yOffset,(HEIGHT*SCALE)+yOffset,SCALE do
				if y > ((HEIGHT*SCALE)+yOffset)-SCALE then continue end
				local pos = Vector3.new(x,y,z)
				March(pos, t_parts, t_cframes)
			end
		end
	end
	
	workspace:BulkMoveTo(t_parts, t_cframes)
	
	-- If Chunk Is Below The Surface (0).
	if self.localPos.Y < 0 then return end
	
	local placementRandom = Random.new(((xOffset*zOffset)/xOffset)+SEED)
	
	-- Performs Poisson Disc Sampling To Get A 2D Grid Of Points To Place Trees At
	local points = PoissonDiscSampling(
		20,                                   -- Radius.
		Vector2.new(WIDTH*SCALE,DEPTH*SCALE), -- Region.
		100,                                  -- Samples.
		placementRandom                       -- Random.
	)
	
	-- Places Trees On The Points
	for _,point in pairs(points) do
		local pos, rotation = raycastToSurface(Vector3.new(point.X, 0, point.Y) + Vector3.new(xOffset, 0, zOffset))
		if (not pos) or (not rotation) then continue end

		local tree = Trees[placementRandom:NextInteger(1, #Trees)]:Clone()
		local dipVal = tree:GetAttribute("dipValue") or 0
		tree:PivotTo(
			CFrame.new(pos + Vector3.new(0, (tree:GetExtentsSize().Y/2)-dipVal, 0))
			* CFrame.Angles(
				0,
				placementRandom:NextInteger(0,360),
				0
			)
		)
		tree.Parent = workspace
	end

end

return PartTerrain
