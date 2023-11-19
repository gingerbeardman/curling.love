deskw,deskh = love.window.getDesktopDimensions( 2 )
w = deskw
h = deskh
print("main monitor size",w.."x"..h)

-- h = 1920

-- scale constants with difference to "100% size"

-- Constants
local WINDOW_HEIGHT = h-70
local PPM = WINDOW_HEIGHT/45	--metres
local WINDOW_WIDTH = PPM * 4.572
local POS_START = WINDOW_HEIGHT - (PPM * (1.829 + 0.07 + 0.1 + 0.1))
local GRAVITY = 9.81 -- m/s^2

-- Rock properties
local MULT = 2
local SCALE = 5
local ROCK_RADIUS = PPM * 0.145	 --m, max
local ROCK_MASS = 18.71 / (SCALE * MULT)	--kgm 17.46 to 19.96
local FRICTION_COEFFICIENT = 0.16	-- ice friction
local COEFFICIENT_OF_RESTITUTION = 0.83 -- Elasticity of the collision
local STOP = 0.05	-- min speed
local MAX = PPM * 2.6	-- m/s
local ROCK_SPEED = MAX -- Initial speed of the rock
local POWER_STEP = (408/(PPM * (2*1.829 + 6.401 + 0.07 + 0.1)))/3	-- inside edge and hack length?

-- Variables
rocks = {}
local totalRocksThrown = 0
local MAX_ROCKS = 16

local ticks = 0
local canBoost = false
local canSweep = false
local sweeping = false
local rocksInMotion = 0

local PLAYER = 1
local CPU = 2
scoreTeam = ""
scorePoints = 0
winner = "START\n"

local cpuPlayer = {
	targetX = 0,
	targetY = 0,
	active = false
}

function love.load()
	rocks = {}
	totalRocksThrown = 0
	rocksInMotion = 0
	
	love.math.setRandomSeed(love.math.random(12))

	-- Set up the window
	love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT)
	love.window.setTitle("Portrait Curling")
	love.graphics.setBackgroundColor( 1,1,1 )
	
	-- Set up the initial rocks
	for e = 1,1 do
		createRockCPU()
	end
	createRock(WINDOW_WIDTH / 2, POS_START , PLAYER)
	
	-- Set up CPU player
	cpuPlayer.targetX = WINDOW_WIDTH / 2
	cpuPlayer.targetY = WINDOW_HEIGHT / 2
end

function love.update(dt)
	 -- Update CPU player behavior
	if cpuPlayer.active and not rockInMotion then
		local cpuRock = rocks[#rocks]
		local targetX = cpuPlayer.targetX
		local targetY = cpuPlayer.targetY
		
		-- Calculate direction towards the target
		local dx = targetX - cpuRock.x
		local dy = targetY - cpuRock.y
		local distance = math.sqrt(dx^2 + dy^2)
		
		-- If the CPU rock is close enough to the target, shoot it
		if distance < 2 * ROCK_RADIUS then
			cpuRock.vx = 0
			cpuRock.vy = -ROCK_SPEED
			rockInMotion = true
		else
			-- Adjust the velocity based on the distance to the target
			local speed = ROCK_SPEED * (distance / (2 * ROCK_RADIUS))
			cpuRock.vx = speed * dx / distance
			cpuRock.vy = speed * dy / distance
		end
	end
	
	rocksInMotion = 0
	local DVX = 1
	local FRICTION = 1
	for i, rock in ipairs(rocks) do
		-- Apply friction to the rock
		local speed = math.sqrt(rock.vx^2 + rock.vy^2)
		if speed > STOP then
			if sweeping == true then
				local FACTOR = (1-FRICTION_COEFFICIENT/2)
				FRICTION = FRICTION_COEFFICIENT * FACTOR
				DVX = rock.dvx * FACTOR
			else
				FRICTION = FRICTION_COEFFICIENT
				DVX = rock.dvx
			end
			local frictionMagnitude = FRICTION * ROCK_MASS * GRAVITY
			local frictionX = -frictionMagnitude * rock.vx / speed
			local frictionY = -frictionMagnitude * rock.vy / speed
			local frictionDX = -frictionMagnitude * rock.dvx / speed
			if rock.y < WINDOW_HEIGHT - (PPM * (3 * 1.829 + 6.401)) then
				rock.vx = rock.vx + DVX + frictionX * dt
				rock.vy = rock.vy + frictionY * dt
				if rock.dvx ~= 0 then
					rock.dvx = rock.dvx + frictionDX * dt
				end
			end
			rocksInMotion = rocksInMotion + 1
		end
		
		-- Update rock position
		rock.x = rock.x + rock.vx * dt
		rock.y = rock.y + rock.vy * dt
		
		-- Check collision with other rocks
		for j, otherRock in ipairs(rocks) do
			if j ~= i and rock.inplay and otherRock.inplay then
				local dx = otherRock.x - rock.x
				local dy = otherRock.y - rock.y
				local distance = math.sqrt(dx^2 + dy^2)
				
				if distance < 2 * ROCK_RADIUS then
					-- Calculate collision response
					local nx = dx / distance
					local ny = dy / distance
					local relativeVelocityX = otherRock.vx - rock.vx
					local relativeVelocityY = otherRock.vy - rock.vy
					local dotProduct = relativeVelocityX * nx + relativeVelocityY * ny
					
					-- Transfer momentum with momentum loss
					local impulse = (-(1 + COEFFICIENT_OF_RESTITUTION) * dotProduct) / (1 / ROCK_MASS + 1 / ROCK_MASS)
					
					-- Apply impulse to rocks
					rock.vx = rock.vx - impulse * nx / ROCK_MASS
					rock.vy = rock.vy - impulse * ny / ROCK_MASS
					otherRock.vx = otherRock.vx + impulse * nx / ROCK_MASS
					otherRock.vy = otherRock.vy + impulse * ny / ROCK_MASS
					
					-- Separate the rocks to prevent overlapping
					local penetration = 2 * ROCK_RADIUS - distance
					local separationX = penetration * nx / (1 / ROCK_MASS + 1 / ROCK_MASS)
					local separationY = penetration * ny / (1 / ROCK_MASS + 1 / ROCK_MASS)
					rock.x = rock.x - separationX / ROCK_MASS
					rock.y = rock.y - separationY / ROCK_MASS
					otherRock.x = otherRock.x + separationX / ROCK_MASS
					otherRock.y = otherRock.y + separationY / ROCK_MASS
				end
			end
		end

		-- Check if the rock is out of bounds or stopped
		if rock.x < ROCK_RADIUS or rock.x > WINDOW_WIDTH - ROCK_RADIUS
		or rock.y < (PPM * 2 * 1.829) or rock.y > POS_START
		or speed < STOP
		then
			rock.vx = 0
			rock.vy = 0
			rock.dvx = 0
			-- winner = ""
			if speed > STOP then
				rock.inplay = false
			end
		end
	end

	canBoost = rocks[#rocks].y > WINDOW_HEIGHT - ((3 * 1.829 + 6.401) * PPM)
	canSweep = rocks[#rocks].y < WINDOW_HEIGHT - ((3 * 1.829) * PPM)
	if love.keyboard.isDown("up") or love.keyboard.isDown("space") then
		if canBoost then
			rocks[#rocks].vy = rocks[#rocks].vy - POWER_STEP	 -- add power

			-- change aim heading
			if love.keyboard.isDown("left") then
				rocks[#rocks].vx = rocks[#rocks].vx - 0.05
			elseif love.keyboard.isDown("right") then
				rocks[#rocks].vx = rocks[#rocks].vx + 0.05
			end

			sweeping = false
		end
	else
		local speed = math.sqrt(rocks[#rocks].vx^2 + rocks[#rocks].vy^2)
		if speed > STOP and canBoost == true then
			-- change curl
			if love.keyboard.isDown("left") then
				rocks[#rocks].dvx = rocks[#rocks].dvx - 0.00005
			elseif love.keyboard.isDown("right") then
				rocks[#rocks].dvx = rocks[#rocks].dvx + 0.00005
			end
		end
		sweeping = false
	end

	if love.keyboard.isDown("down") then
		if canSweep == true then
			sweeping = true
		end
	end

	if canBoost == false then
		-- grey = free rolling
		love.graphics.setColor( 0.25,0.25,0.25 )
	end

	if rocksInMotion == 0 and rocks[#rocks].y ~= POS_START then
		createRockCPU()
		createRock(WINDOW_WIDTH / 2, POS_START , PLAYER)
	end

	ticks = ticks + 1
end

function love.draw()
	for off=1,2 do
		if off == 1 then
			offy = 0
			offm = 1
		else
			offy = WINDOW_HEIGHT
			offm = -1
		end

		-- hack lines
		love.graphics.setColor( 0,0,0 )
		love.graphics.setLineWidth( PPM * 0.1 )
		local y = (1.829+0.07/2) * PPM
		love.graphics.line(WINDOW_WIDTH/2-(PPM*0.45/2),offy+offm*y,WINDOW_WIDTH/2-(PPM*0.07),offy+offm*y)
		love.graphics.line(WINDOW_WIDTH/2+(PPM*0.07),offy+offm*y,WINDOW_WIDTH/2+(PPM*0.45/2),offy+offm*y)
		love.graphics.setLineWidth( 0 )
		
		-- back lines
		love.graphics.setColor( 0,0,0, 0.25 )
		local y = 2 * 1.829 * PPM
		love.graphics.line(0,offy+offm*y,WINDOW_WIDTH,offy+offm*y)
	
		-- tee
		love.graphics.setColor( 0.8,0,0 )
		love.graphics.circle("fill", WINDOW_WIDTH/2, offy+offm* (PPM * 3 * 1.829), PPM * 1.829)
		love.graphics.setColor( 1,1,1 )
		love.graphics.circle("fill", WINDOW_WIDTH/2, offy+offm* (PPM * 3 * 1.829), PPM * 1.219)
		love.graphics.setColor( 0,0,0.8 )
		love.graphics.circle("fill", WINDOW_WIDTH/2, offy+offm* (PPM * 3 * 1.829), PPM * 0.610)
		love.graphics.setColor( 1,1,1 )
		love.graphics.circle("fill", WINDOW_WIDTH/2, offy+offm* (PPM * 3 * 1.829), PPM * 0.152)

		-- tee lines
		love.graphics.setColor( 0,0,0, 0.25 )
		local y = 3 * 1.829 * PPM
		love.graphics.line(0,offy+offm*y,WINDOW_WIDTH,offy+offm*y)
	
		-- center lines
		love.graphics.setColor( 0,0,0, 0.125 )
		local y = 1.829 * PPM
		love.graphics.line(WINDOW_WIDTH/2,y,WINDOW_WIDTH/2,WINDOW_HEIGHT-y)
	
		-- hog lines
		love.graphics.setLineWidth( PPM * 0.1)
		love.graphics.setColor( 0.7,0,0 )
		local y = (3 * 1.829 + 6.401) * PPM
		love.graphics.line(0,offy+offm*y,WINDOW_WIDTH,offy+offm*y)
	end
	
	-- Draw the rocks
	for n, rock in ipairs(rocks) do
		local alpha = 1
		if rock.inplay == false then
			alpha = 0.4
		end
	
		if n == #rocks and sweeping == true then
			love.graphics.setColor( 0.2,0.8,1 )
			love.graphics.circle("line", rock.x, rock.y, ROCK_RADIUS*2)
		end
	
		love.graphics.setColor( 0.66,0.66,0.66, alpha )
		love.graphics.circle("fill", rock.x, rock.y, ROCK_RADIUS)
		if rock.team == PLAYER then
			love.graphics.setColor( 0.8,0,0, alpha/2 )
		else
			love.graphics.setColor( 0,0,1, alpha/2 )
		end
		love.graphics.circle("fill", rock.x, rock.y, ROCK_RADIUS*0.6)

		local speed = math.sqrt(rock.vx^2 + rock.vy^2)
		-- grey = free rolling
		love.graphics.setColor( 0.25,0.25,0.25 )
		if speed > 0 and rock.team == PLAYER then
			if canBoost then
				if love.keyboard.isDown("up") or love.keyboard.isDown("space") then
					-- green = boosting
					love.graphics.setColor( 0,0.75,0 )
				else
					-- yellow = not boosting
					love.graphics.setColor( 1,0.75,0 )
				end
			end
			if rock.y > WINDOW_HEIGHT - (PPM * (3 * 1.829 + 6.401)) then
				showvals = "%2d\n%0.1f\n%0.1f"
			else
				showvals = "%2d"
			end
			love.graphics.print(string.format(showvals, speed, rock.vx, rock.dvx* 1000), rock.x-7,rock.y+7)
			if WINDOW_HEIGHT > deskh then
				love.graphics.print(string.format(showvals, speed, rock.vx, rock.dvx* 1000), WINDOW_WIDTH/2,10)
			end
		end
	end

	if scoreTeam == "CPU" then
		love.graphics.setColor( 0,0,1 )
	else
		love.graphics.setColor( 0.8,0,0 )
	end
	love.graphics.print(string.format("%s%s %d", winner, scoreTeam, scorePoints), 2,2)

--	love.graphics.print(string.format("moving: %d", rocksInMotion), 2,2)
end

function createRock(x, y, t)
	local rock = {
		x = x,
		y = y,
		vx = 0,
		vy = 0,
		dvx = 0,
		team = t,
		inplay = true
	}
	table.insert(rocks, rock)
	
	totalRocksThrown = totalRocksThrown + 1

	if totalRocksThrown == MAX_ROCKS + 1 then
		winner = "WINNER ".. scoreTeam .." ".. scorePoints .. "\n"
		love.load()
	elseif #rocks > 2 then
		winner = ""
	end

	calcScores()
end

function createRockCPU()
	createRock(WINDOW_WIDTH/2 + love.math.random(-WINDOW_WIDTH/4, WINDOW_WIDTH/4), love.math.random(PPM * 2 * 1.829, PPM * 4 * 1.829), CPU)
end

-- Function to calculate the distance between two points
local function calculateDistance(x1, y1, x2, y2)
	local dx = x2 - x1
	local dy = y2 - y1
	return math.sqrt(dx^2 + dy^2)
end

-- Function to sort rocks by distance from a point
function sortRocksByDistance(rocks, pointX, pointY)
	table.sort(rocks, function(a, b)
		local distanceA = calculateDistance(a.x, a.y, pointX, pointY)
		local distanceB = calculateDistance(b.x, b.y, pointX, pointY)
		return distanceA < distanceB
	end)
end

function calcScores()
	tx = WINDOW_WIDTH/2
	ty = (PPM * 3 * 1.829)
	
	sorted = {unpack (rocks)}
	
	sortRocksByDistance(sorted, tx, ty)
	
	-- Draw the rocks
--	print("distances")
	local closestRocks = 0
	local closestTeam = nil
	local closestChange = false
	for n, rock in ipairs(sorted) do
		if rock.inplay == true and rock.y < PPM * (3 * 1.829 + 6.401) then
--			print((closestTeam == CPU and "CPU" or "PLAYER"), calculateDistance(rock.x, rock.y, tx,ty))

			if closestTeam == nil then
				closestTeam = rock.team
				closestRocks = closestRocks + 1
			elseif closestChange == false and rock.team == closestTeam then
				closestRocks = closestRocks + 1
			elseif rock.team ~= closestTeam then
				closestChange = true
			end
		end
	end
	scoreTeam = (closestTeam == CPU and "CPU" or "PLAYER")
	scorePoints = closestRocks
--	print("scores")
--	print(scoreTeam, scorePoints)
end
