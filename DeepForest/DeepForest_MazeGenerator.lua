-- "maze.lua" from https://github.com/shironecko/LuaMaze, under the MIT License.
-- (With Maze renamed to MazeGen to avoid conflicts with DeepForest_Maze.)

-- Copyright (c) 2014 Vitaliy Sich
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

-- https://github.com/shironecko/LuaMaze

local MazeGen =
{
  directions =
  {
    north = { x = 0, y = -1 },
    east  = { x = 1, y = 0 },
    south = { x = 0, y = 1 },
    west  = { x = -1, y = 0 }
  }
}

function MazeGen:new( width, height, closed, obj )
  obj = obj or {}
  setmetatable(obj, self)
  self.__index = self

  -- Actual maze setup
  for y = 1, height do
    obj[y] = {}
    for x = 1, width do
      obj[y][x] = { east = obj:CreateDoor(closed), south = obj:CreateDoor(closed)}

      -- Doors are shared beetween the cells to avoid out of sync conditions and data dublication
      if x ~= 1 then obj[y][x].west = obj[y][x - 1].east
      else obj[y][x].west = obj:CreateDoor(closed) end

      if y ~= 1 then obj[y][x].north = obj[y - 1][x].south
      else obj[y][x].north = self:CreateDoor(closed) end
    end
  end

  return obj
end

function MazeGen:width()
  return #self[1]
end

function MazeGen:height()
  return #self
end

function MazeGen:DirectionsFrom(x, y, validator)
  local directions = {}
  validator = validator or function() return true end

  for name, shift in pairs(self.directions) do
    local x, y = x + shift.x, y + shift.y

    if self[y] and self[y][x] and validator(self[y][x], x, y) then
      directions[#directions + 1] = { name = name, x = x, y = y }
    end
  end

  return directions
end

function MazeGen:ResetDoors(close, borders)
  for y = 1, #self do
    for i, cell in ipairs(self[y]) do
      cell.north:SetClosed(close or y == 1 and not borders)
      cell.west:SetClosed(close)
    end

    self[y][1].west:SetClosed(close or not borders)
    self[y][#self[1]].east:SetClosed(close or not borders)
  end

  for i, cell in ipairs(self[#self]) do
    cell.south:SetClosed(close or not borders)
  end
end

function MazeGen:ResetVisited()
  for y = 1, #self do
    for x = 1, #self[1] do
      self[y][x].visited = nil
    end
  end
end

function MazeGen.tostring(maze, wall, passage)
  wall = wall or "#"
  passage = passage or " "

  local result = ""

  local verticalBorder = ""
  for i = 1, #maze[1] do
    verticalBorder = verticalBorder .. wall .. (maze[1][i].north:IsClosed() and wall or passage)
  end
  verticalBorder = verticalBorder .. wall
  result = result .. verticalBorder .. "\n"

  for y, row in ipairs(maze) do
    local line = row[1].west:IsClosed() and wall or passage
    local underline = wall
    for x, cell in ipairs(row) do
      line = line .. " " .. (cell.east:IsClosed() and wall or passage)
      underline = underline .. (cell.south:IsClosed() and wall or passage) .. wall
    end
    result = result .. line .. "\n" .. underline .. "\n"
  end

  return result
end

MazeGen.__tostring = MazeGen.tostring

function MazeGen:CreateDoor(closed)
  local door = {}
  door.closed = closed and true or false

  function door:IsClosed()
    return self.closed
  end

  function door:IsOpened()
    return not self.closed
  end

  function door:Close()
    self.closed = true
  end

  function door:Open()
    self.closed = false
  end

  function door:SetOpened(opened)
    if opened then
      self:Open()
    else
      self:Close()
    end
  end

  function door:SetClosed(closed)
    self:SetOpened(not closed)
  end

  return door
end

----------------------------------------------------------------------------------------
-- "kruskal.lua" from https://github.com/shironecko/LuaMaze, also under the MIT License.

-- Kruskal's algorithm
-- Detailed description: http://weblog.jamisbuck.org/2011/1/3/maze-generation-kruskal-s-algorithm
local random = math.random

local function kruskal(maze)
  maze:ResetDoors(true)

  local sets = {}
  local walls = {}
  for y = 1, maze:height() do
    for x = 1, maze:width() do
      -- Sets
      local currCell = maze[y][x]
      local setID = (y - 1) * #maze[1] + x
      sets[setID] = { [currCell] = true }
      currCell.set = setID

      -- Walls list
      if x ~= maze:width() then 
        walls[#walls + 1] = { from = currCell, to = maze[y][x + 1], direction = "east" } 
      end
      if y ~= maze:height() then
        walls[#walls + 1] = { from = currCell, to = maze[y + 1][x], direction = "south" }
      end
    end
  end

  while #walls ~= 0 do
    -- Choosing a random wall to process, then removing it from the walls list
    local rnd_i = random(#walls)
    local wall = walls[rnd_i]
    walls[rnd_i] = walls[#walls]
    walls[#walls] = nil

    if wall.from.set ~= wall.to.set then
      -- Carve
      wall.from[wall.direction]:Open()

      -- Merge sets
      local lSet = wall.from.set
      local rSet = wall.to.set
      for cell, _ in pairs(sets[rSet]) do
        sets[lSet][cell] = true
        cell.set = lSet
      end
      sets[rSet] = nil
    end
  end

  -- Clean sets data
  for y = 1, maze:height() do
    for x = 1, maze:width() do
      maze[y][x].set = nil
    end
  end
end
----------------------------------------------------------------------------------------
-- DeepForest-specific code.

-- We have to be a bit arms-length here, since we're json-encoding these.
-- That means no meta-tables! Not unless we want to restore them constantly.
function coerceToMaze(mazegen)
	-- The original maze object layout is a height-by-width grid of cells.
	-- Each cell has east, south, west, and north "doors".
	-- Each "door" is either open or closed; closed doors are walls.

	-- We're going to do a lossy transformation here and lose this door information.
	--
	-- Boy would I kill for some bitwise operators right about now...
	-- Imagine: all four directions could be packed into a single number!
	-- Then we could do away with cell tables altogether and just store the numbers!
	-- Think of the minor filesize optimizations!
	local ret = {}

	for y = 1, mazegen:height() do
		ret[y] = {}
		for x = 1, mazegen:width() do
			local cell = {}
			local oldCell = mazegen[y][x]
			ret[y][x] = cell

			-- Let's trim the json here by naming each direction one char.
			if oldCell.north ~= nil and oldCell.north:IsOpened() then
				cell.n = true
			end
			if oldCell.east ~= nil and oldCell.east:IsOpened() then
				cell.e = true
			end
			if oldCell.south ~= nil and oldCell.south:IsOpened() then
				cell.s = true
			end
			if oldCell.west ~= nil and oldCell.west:IsOpened() then
				cell.w = true
			end
		end
	end

	return ret
end

function createMaze(size)
	local maze = MazeGen:new(size, size, true)

	kruskal(maze)

	return coerceToMaze(maze)
end

function checkMaze()
	if Maze.get() == nil then
		Maze.set(createMaze(MazeAPI.size()))
	end
end

checkMaze()
Maze.setPos(1, 1) -- Back to the entrance.
Log('FOREST_ENTRY')
SetScene('DeepForest_MazeScene')