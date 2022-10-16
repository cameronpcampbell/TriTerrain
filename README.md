# TriTerrain

| WARNING: DO NOT USE THIS TERRAIN SYSTEM FOR ANY REAL GAMES |
| --- |
| Because The terrain is made out of WedgeParts it is not performant and should not be used for any real games. |

- - -

# How To Use
either get the system from the `src` folder on this repo or grab it from roblox [here](#). Then put in in `ReplicatedStorage` or `ServerStorage` (for example).

## API
```
-- Inits The Part Pool For Storing The WedgeParts. YOU MUST DO THIS BEFORE GENERATING TERRAIN.
TriTerrain.init()
```

```
-- Creates Data For A New Chunk At The Specified Coords.
TriTerrain.new(x,y,z) -> Chunk
```

```lua
-- Generates The Chunk.
Chunk:gen()
```

## Example Script
```lua
local TriTerrainFolder = game:GetService("ReplicatedStorage").TriTerrain
local TriTerrain = require(TriTerrainFolder.Generator)
local Swait = require(TriTerrainFolder.Swait)

local WIDTH, DEPTH, HEIGHT = 2,2,1

-- Inits The Part Pool.
TriTerrain.init(13000*WIDTH*DEPTH*HEIGHT)

print("Starting")
local start = tick()


-- Generates The Chunks.
for x = 0,(WIDTH-1) do
	for z = 0,(DEPTH-1) do
		for y = -HEIGHT,0 do
			TriTerrain.new(x,y,z):gen()
		end
	end
	Swait()
end

-- Prints The Amount Of Time It Took To Generate.
print(tick()-start)

```
