-- Handles going in a direction.
function go(stepX, stepY)
	local pos = Maze.getPos()
	local maze = Maze.get()

	local tile = maze[pos[2]]
	if tile then tile = tile[pos[1]] end

	local exit = MazeAPI.findExit(pos[1] + stepX, pos[2] + stepY)

	-- Double-check we can actually go there.
	if not checkInternal(stepX, stepY, tile, exit) then
		error('Bad position: ' .. tostring(pos[1] + stepX) .. ', ' .. tostring(pos[2] + stepY) .. ' (tried ' .. EXP_tabletostring(tile) .. ' and ' .. EXP_tabletostring(exit) .. ')')
	end

	-- If we're exiting, we should keep the position we
	-- were in so that returning puts us in the same spot.
	-- That way the exit can just pop us back in the scene
	-- when they're done and we'll be right where we were.
	if not exit then
		pos[1] = pos[1] + stepX
		pos[2] = pos[2] + stepY
		Maze.setPos(pos[1], pos[2])
	end

	-- One hour seems like a bit much, but I suspect Finmer will yeet
	-- me if I so much as think about passing a float into here.
	AdvanceTime(1)

	if exit then
		exit[4]()
	else
		-- Display some generic "congrats, you moved" text.
		Log(GetIsNight() and "FOREST_NO_EVENT_NIGHT" or "FOREST_NO_EVENT_DAY")
		-- Refresh the scene.
		SetScene('DeepForest_MazeScene')
	end
end

-- Makes sure that going in a direction is actually valid, based on the provided data.
function checkInternal(stepX, stepY, tile, exit)
	if not exit then
		if not tile then return false end
		if stepX > 0 and not tile.e then return false end
		if stepX < 0 and not tile.w then return false end
		if stepY > 0 and not tile.s then return false end
		if stepY < 0 and not tile.n then return false end
	end
	return true
end

-- Makes sure that going in a direction is actually valid.
function check(stepX, stepY)
	local pos = Maze.getPos()
	local x = pos[1]
	local y = pos[2]

	local maze = Maze.get()
	if x < 0 or y < 0 or y > #maze or x > #maze[1] then return false end

	local tile = maze[y]
	if tile then tile = tile[x] end

	local exit = MazeAPI.findExit(x + stepX, y + stepY)

	-- If the exit defines a condition which has not been satisfied, pretend there isn't actually an exit.
	if exit and exit[5] and not exit[5]() then
		exit = nil
	end

	return checkInternal(stepX, stepY, tile, exit)
end

-- Invoked to refresh the location and available exits, and also prints the scene description.
--
-- "full" determines whether to print the full description versus just the ring guidance.
-- It's used to refresh the display after activating the ring.
function refreshDisplay(full)
	-- <player name> has made the advancement [We Need to Go Deeper]

	local pos = Maze.getPos()

	SetLocation('Deep in the Forest')

	-- Run callbacks here so that scene changes don't have
	-- to put up with whatever text we spew out below.
	if MazeAPI._moveCallback then
		MazeAPI._moveCallback()
	end

	local directions = {}

	-- Thank dog we don't need 2⁴ state nodes for this.
	if check(0, -1) then
		table.insert(directions, 'north')
		AddLink(ECompass.North, function() go(0, -1) end)
	end
	if check(1,  0) then
		table.insert(directions, 'east')
		AddLink(ECompass.East,  function() go(1,  0) end)
	end
	if check(0,  1) then
		table.insert(directions, 'south')
		AddLink(ECompass.South, function() go(0,  1) end)
	end
	if check(-1, 0) then
		table.insert(directions, 'west')
		AddLink(ECompass.West,  function() go(-1, 0) end)
	end

	-- Add the "you are in *THE DEEP FOREST*" heading.
	local text = full and Text.GetString('DEEPFOREST_HEADING') or ''

	-- Some customization data for the time of day and whether the ring is active.
	local time = GetIsNight() and 'NIGHT' or 'DAY'
	local ring = (Storage.GetFlag('DEEPFOREST_RING_USED') and not Storage.GetFlag('FOREST_ADEPT_FIRST')) and '_RING' or ''

	if full then
		-- Add the main description.
		text = text .. ' ' .. Text.GetString('DEEPFOREST_CONTENT_' .. time .. ring)

		-- Add the direction description, i.e. the "you can go x, y, and z" stuff.
		if #directions == 4 then
			text = text .. ' ' .. Text.GetString('DEEPFOREST_ALL_DIRECTIONS')
		elseif #directions == 1 then
			Text.SetVariable('direction', directions[1])
			Text.SetVariable('direction caps', CapFirst(directions[1]))
			text = text .. ' ' .. Text.GetString('DEEPFOREST_SINGLE_DIRECTION')
		else
			local _and = stringifyArray(directions, 'and')
			local _or = stringifyArray(directions, 'or')
			Text.SetVariable('directions and', _and)
			Text.SetVariable('directions and caps', CapFirst(_and))
			Text.SetVariable('directions or', _or)
			Text.SetVariable('directions or caps', CapFirst(_or))
			text = text .. ' ' .. Text.GetString('DEEPFOREST_DIRECTIONS')
		end
	end

	-- Add the ring guidance description.
	if ring ~= '' then
		-- Do some path-finding.
		local path = MazeAPI.findPath(Maze.get(), pos[1], pos[2], 1, 11)
		-- Whoops, guess the ring is faulty.
		if path == false then error('Could not pathfind to Rux') end

		local nextPos = path[2] -- Our current location is the first path element.

		-- Try to work out the direction we need to travel in.
		local direction
		if nextPos.x == pos[1] then -- Only the y coordinate differs.
			if nextPos.y > pos[2] then
				direction = 'south'
			else
				direction = 'north'
			end
		elseif nextPos.y == pos[2] then -- Only the x coordinate differs.
			if nextPos.x > pos[1] then
				direction = 'east'
			else
				direction = 'west'
			end
		else
			-- What
			error('Path node differs in both dimensions')
		end

		-- Actually add the text.
		Text.SetVariable('direction', direction)
		text = text .. (full and ' ' or '') .. Text.GetString('DEEPFOREST_RING_HINT')
	end

	-- Print the text.
	LogRaw(text)

	--LogRaw('DEBUG MAP:\n' .. Maze.tostring(Maze.get(), '1', '0'))
end

-- Given an array, formats it into:
-- 1) "a"
-- 2) "a and b"
-- 3) "a, b, and c"
function stringifyArray(array, conj)
	local ret = ''
	local len = #array

	for i, v in ipairs(array) do
		if ret == '' then
			ret = v
		else
			if len > 2 then ret = ret .. ',' end
			ret = ret .. ' '
			if i == len then ret = ret .. conj .. ' ' end
			ret = ret .. v
		end
	end

	return ret
end

-- Some general utilities for nicer table printing.
-- Otherwise we just have "table: 82a53b9f".
function EXP_tabletostring(tbl, indent)
	if type(tbl) ~= 'table' then return tostring(tbl) end
	if indent == nil then indent = '' end

	local array = true

	for k, v in pairs(tbl) do
		if type(k) ~= 'number' then
			array = false
			break
		end
	end

	local ret = '{'

	for k, v in pairs(tbl) do
		local ind = indent .. '  '
		if not array then
			ret = ret .. '\n' .. ind
			ret = ret .. EXP_wraptostring(k, ind) .. ': '
		else
			ret = ret .. ' '
		end
		ret = ret .. EXP_wraptostring(v, ind)
	end

	if not array then
		ret = ret .. '\n' .. indent .. '}'
	else
		ret = ret .. ' }'
	end

	return ret
end

function EXP_wraptostring(thing, indent)
	if type(thing) == 'string' then
		return '"' .. thing .. '"'
	else
		return EXP_tabletostring(thing, indent)
	end
end