MazeAPI = { _size = 10, _exits = {}, _moveCallback = nil }

-- Returns the size of the maze, in both directions.
function MazeAPI.size()
	return MazeAPI._size
end

function MazeAPI.increaseSize(by)
	-- Don't let people shrink the maze. That could have unforseen consequences.
	if by > 0 then
		MazeAPI._size = MazeAPI._size + by
	end
end

-- Attempts to locate and return the exit at the specified location.
-- If there's no exit there, returns nil.
function MazeAPI.findExit(x, y)
	if type(x) ~= 'number' then error('x is not a number, is: ' .. tostring(x)) end
	if type(y) ~= 'number' then error('y is not a number, is: ' .. tostring(y)) end

	for _, exit in ipairs(MazeAPI._exits) do
		if exit[1] == x and exit[2] == y then
			return exit
		end
	end

	return nil
end

-- Add an exit to the maze. Exits must be on the "edge" of the maze.
-- The coordinates [1, 1] corresponds to the top-left cell of the maze.
-- Exits must have coordinates corresponding to "just outside" the maze.
-- That is, a sort of imaginary border around the maze extending from [0, 0] to [size + 1, size + 1].
-- See some examples at the end of this file.
--
-- Parameters:
--     x — The x position of the exit. This must be one cell outside the maze.
--     y — The y position of the exit. This must be one cell outside the maze.
--     name — The name of the exit. This serves as an identifier for e.g. error conditions.
--     callback — A function to run when the player navigates to this exit.
--     condition — A function to determine whether the exit is available. May be nil.
--                 The function should return a boolean indicating whether the exit exists.
--                 If it returns false (or some non-boolean value) then the exit will be treated as though it never existed.
--                 This can be used to gate places behind having certain items, or to prevent the player from visiting a place twice.
--
-- Returns:
--     true.
function MazeAPI.addExit(x, y, name, callback, condition)
	if type(x) ~= 'number' then
		error('Cannot add exit with non-number x position.')
	end
	if type(y) ~= 'number' then
		error('Cannot add exit with non-number y position.')
	end
	if type(name) ~= 'string' then
		error('Cannot add exit with non-string name.')
	end
	if type(callback) ~= 'function' then
		error('Cannot add exit with non-function callback.')
	end
	if condition ~= nil and type(condition) ~= 'function' then
		error('Cannot add exit with non-function condition.')
	end

	local size = MazeAPI.size()
	if x < 0 or y < 0 or x > size + 1 or y > size + 1
	-- NW corner
	or (x == 0 and y == 0)
	-- NE corner
	or (x == size + 1 and y == 0)
	-- SE corner
	or (x == size + 1 and y == size + 1)
	-- SW corner
	or (x == 0 and y == size + 1)
	then
		error('Cannot add exit at [' .. x .. ', ' .. y .. '] as that position is outside the maze.')
	end

	-- We don't bother validating that the position is actually on the edge, as that's a bit complicated.

	local original = MazeAPI.findExit(x, y)
	-- Allow replacing existing exits, for say, if a mod wants to expand one.
	-- However, the names have to match.
	if original ~= nil and name ~= original[3] then
		error('Cannot add new exit at [' .. x .. ', ' .. y .. '] as it is already taken by "' .. original[3] .. '".')
	end

	-- Coerce nil condition to dummy true condition.
	if condition == nil then
		condition = function() return true end
	end

	table.insert(MazeAPI._exits, { x, y, name, callback, condition })

	return true
end

-- Adds the specified callback to run every time the player moves in the maze.
function MazeAPI.addMoveCallback(callback)
	if MazeAPI._callback ~= nil then
		local old = MazeAPI._callback
		MazeAPI._callback = function()
			old()
			callback()
		end
	else
		MazeAPI._callback = callback
	end
end

-- Attempts to find the shortest path from `start` to `target` in the given maze.
--
-- Parameters:
--     maze — The maze in question.
--     startX — The x coordinate of the starting location. Must be 0 <=> MazeAPI.size() + 1.
--     startY — The y coordinate of the starting location. Must be 0 <=> MazeAPI.size() + 1.
--     targetX — The x coordinate of the target location. Must be 0 <=> MazeAPI.size() + 1.
--     targetY — The y coordinate of the target location. Must be 0 <=> MazeAPI.size() + 1.
--
-- Returns:
--     A list of tables containing `x` and `y` keys representing the path to the specified target, or false if no path is possible.
function MazeAPI.findPath(maze, startX, startY, targetX, targetY)
	local width = #maze[1] + 2
	local height = #maze + 2

	local ret = DeepForestAstar:find(
		width, height,
		-- We must "re-center" these so they're ≥1.
		{ x = startX + 1, y = startY + 1 },
		{ x = targetX + 1, y = targetY + 1 },
		function(x2, y2, x1, y1, stepX, stepY)
			return MazeAPI.pathFilter(maze, x2, y2, x1, y1, stepX, stepY, width, height)
		end,
		false, -- Caching is disabled because I'm not sure how it interacts with save data.
		true -- No diagonal movement here.
	)

	if type(ret) == 'table' then
		for _, pos in ipairs(ret) do
			pos.x = pos.x - 1
			pos.y = pos.y - 1
		end
	end

	return ret
end

function MazeAPI.pathFilter(maze, x2, y2, x1, y1, stepX, stepY, width, height)
	-- Go ahead and make sure we don't try to handle non-adjacent paths.
	if x1 ~= x2 and y1 ~= y2 then
		error('It\'s only diagonal if it comes from the diagonal part of Finmer, otherwise it\'s just sparkling edge-cases.')
	end

	local inExit = x1 == 1 or y1 == 1 or x1 == width or y1 == height
	local toExit = x2 == 1 or y2 == 1 or x2 == width or y2 == height

	local realX1 = x1 - 1
	local realY1 = y1 - 1
	local realX2 = x2 - 1
	local realY2 = y2 - 1

	if toExit then -- Attempting to no-clip into the border of the maze. Only legal if there's an exit there, otherwise you're sentenced to the backrooms.
		local exit = MazeAPI.findExit(realX2, realY2)
		return exit and true or false
	else -- We're going to a tile.
		local to = maze[realY2]
		if to then to = to[realX2] end

		-- Does your forest normally have chunk errors?
		if not to then
			LogRaw('DeepForest ERROR: Position ' .. realX2 .. ', ' .. realY2 .. ' doesn\'t exist!', Color(255, 0, 0))
			return false
		end
	end

	-- Currently inside an exit -- going to other exits is prohibited (they're not rather fond of this kind of sequence-breaking).
	if inExit then
		return not toExit
	end

	local cur = maze[realY1][realX1]

	-- Do some direction checks. Hopefully these are right.
	if stepX ==  1 and not cur.e then return false end -- Going east.
	if stepX == -1 and not cur.w then return false end -- Going west.
	if stepY ==  1 and not cur.s then return false end -- Going south.
	if stepY == -1 and not cur.n then return false end -- Going north.

	return true
end

-- Top-left corner, in the western wall.
MazeAPI.addExit(0, 1, 'Deep Forest: Entrance', function()
	Log('FOREST_EXIT')
	SetScene('Scene_ForestCottage')
end)

-- Bottom-right corner, in the southern wall.
MazeAPI.addExit(10, 11, 'Deep Forest: Encounters', function()
	-- The following code "borrowed" from the base game.
	-------------------------------------------
	-- Roll a random encounter
	local encounter = Encounter.Roll(k_EncounterGroup_Forest)
	if encounter == nil then
		-- No encounter; display placeholder text
		Log(GetIsNight() and "FOREST_NO_EVENT_NIGHT" or "FOREST_NO_EVENT_DAY")
	else
		-- Run encounter script
		encounter()
	end
	-------------------------------------------
end)

-- Bottom-left corner, in the southern wall.
MazeAPI.addExit(1, 11, 'Deep Forest: Rux\'s Cabin', function()
	SetScene('Scene_ForestAdept')
end, function()
	-- Unlike the original, you can always retrace your steps and take the long route, if you want.
	--
	-- MQ03_DONE: Make sure the player is *actually* at the right part of the story.
	-- DEEPFOREST_RING_USED: Make sure the path is only available if the player has used the ring before.
	-- FOREST_ADEPT_FIRST: For saves that have ventured past this point *without* the mod, ensures the path is still open (since RING_USED will be false).
	return Storage.GetFlag('MQ03_DONE') and (Storage.GetFlag('DEEPFOREST_RING_USED') or Storage.GetFlag('FOREST_ADEPT_FIRST'))
end)

-- I think it's funny how there's a whole three naming conventions in play.
-- We've got Lua, with things like extracooltostringwithepicnilhandling(sometable);
-- we have C#, with things like Storage.GetFlag('Some Very Cool Boolean');
-- and then we have Java, with things like theUnsafe.objectFieldOffset(randall.getClass().getDeclaredField("health")).

-- I *think* this is unnecessary, but it doesn't hurt to leave it in.
return MazeAPI