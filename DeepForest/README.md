# Deep Forest

This is a module for Finmer that replaces the existing "deep forest" with a maze!
This maze is randomly-generated when you first enter the forest, meaning every
playthrough is slightly different.
Some parts of the Core module have been moved to specific parts of the maze, such as the direwolf side-quest and the ring part of the main quest.

This module is fairly invasive; parts of the story had to be altered very slightly for things to work. (The alterations aren't anything too major -- just moving some things around.)
Don't expect it to necessarily play nicely with other modules that touch the forest.

This module *does* come with some semblance of an API.
Other modules may use [`MazeAPI`](DeepForest_MazeAPI.lua) to interface with it.
The API primarily exposes the ability to add new "exits," although it allows a few other things too.

Deep Forest contains three libraries, all under the MIT license: [json.lua](https://github.com/rxi/json.lua) (at [DeepForest_Json](DeepForest_Json.lua)), parts of [LuaMaze](https://github.com/shironecko/LuaMaze) (at [DeepForest_MazeGenerator](DeepForest_MazeGenerator.lua)), and [lua-star](https://github.com/wesleywerner/lua-star) (at [DeepForest_Astar](DeepForest_Astar.lua)).
The license terms of each are reproduced in each of those files.