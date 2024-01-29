Maze = { _current = nil }

function Maze:tostring(wall, passage)
	local result = ''

	local verticalBorder = ''
	for x = 1, #self[1] do
		verticalBorder = verticalBorder .. wall .. ((self[1][x].n or MazeAPI.findExit(x, 0)) and passage or wall)
	end
	verticalBorder = verticalBorder .. wall
	result = result .. verticalBorder .. '\n'

	local pos = Maze.getPos()

	for y, row in ipairs(self) do
		local line = (row[1].w or MazeAPI.findExit(0, y)) and passage or wall
		local underline = wall
		for x, cell in ipairs(row) do
			local mid = (x == pos[1] and y == pos[2]) and 'X' or passage
			line = line .. mid .. ((cell.e or MazeAPI.findExit(x + 1, y)) and passage or wall)
			underline = underline .. ((cell.s or MazeAPI.findExit(x, y + 1)) and passage or wall) .. wall
		end
		result = result .. line .. '\n' .. underline .. '\n'
	end

	return result
end

function Maze:toJson()
	return DeepForestJson.encode(self)
end

function Maze.fromJson(json)
	return DeepForestJson.decode(json)
end

-- Returns the current maze. May be nil if it hasn't been generated yet.
function Maze.get()
	-- I'm gonna be honest: "nilable" really just doesn't have the same ring to it that "nullable" does.
	if Maze._current == nil then
		local json = Storage.GetString('DeepForestMaze')
		if json ~= '' then
			Maze._current = Maze.fromJson(json)
		end
	end

	return Maze._current
end

-- Sets the current maze.
function Maze:set()
	Maze._current = self
	Storage.SetString('DeepForestMaze', Maze.toJson(self))
end

-- Returns the player's current position in the maze as a table ({ x, y }).
function Maze.getPos()
	-- If these are floats I'm gonna have to throw someone.
	local ret = { Storage.GetNumber('DeepForestMazeX'), Storage.GetNumber('DeepForestMazeY') }

	-- Initialize these numbers to sane values.
	if ret[1] == 0 and ret[2] == 0 then
		ret[1] = 1
		ret[2] = 1
	end

	return ret
end

-- Sets the player's current position in the maze.
function Maze.setPos(x, y)
	Storage.SetNumber('DeepForestMazeX', x)
	Storage.SetNumber('DeepForestMazeY', y)
end