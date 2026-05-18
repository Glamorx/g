To play the game copy 3 files to your pc (fix_it_faster.console.exe, fix_it_faster.exe, fix_it_faster.pck,)
Open *.exe and it should work.

Files:
counter.gd - everything in game, passing info to map builder, resising to level, adjusting player, car positions to default and camera ofc. Creating arror for player when he isn't visible ( not working so good ). Spawning random parts toggling pause menu

engine_part.gd - is the part that you need to collect
engine_part.tscn - part

game_state.gd - game states, unlocking levels, saving, loading, reset, unlock progres

mainmenu.gd - main menu 
mainmenu.tscn - adjusting a menu

map_builder.gd - Map generator, creating 4 types of trees and adding materials to it, creating rocks, place in map

move.gd - able player to move

pause_menu.gd - pause menu
pause_menu.tscn - pause menu

repair_zone.gd zone

ui.gd - player ui