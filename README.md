# Fix it Faster

![Godot Engine](https://img.shields.io/badge/Godot_4.6.2-478CBF?style=for-the-badge&logo=godot-engine&logoColor=white) ![GDScript](https://img.shields.io/badge/Language-GDScript-355570?style=for-the-badge) ![Platform Windows](https://img.shields.io/badge/Platform-Windows-blue?logo=microsoft) ![Claude](https://img.shields.io/badge/Claude-D97757?style=for-the-badge&logo=claude&logoColor=white)

## Instalation
To play the game copy 2 files to your pc (`fix_it_faster.exe`, `fix_it_faster.pck`)

Open `fix_it_faster.exe`


## Description

Game about collecting parts to fix a car and drive away from forest.

## Controls

WASD or Arrows to Move

E - Use car

## Roadmap
Future implements:
- [ ] Adding a wild animals to forest
- [ ] Adding a weapons to fight with animals
- [ ] Adding a night time
- [ ] Adding a Scoreboard and timers for speedrunners



## Files:
`counter.gd` - everything in game, passing info to map builder, resising to level, adjusting player, car positions to default and camera ofc. Creating arror for player when he isn't visible ( not working so good ). Spawning random parts toggling pause menu

`engine_part.gd` - is the part that you need to collect
`engine_part.tscn` - part

`game_state.gd` - game states, unlocking levels, saving, loading, reset, unlock progres

`mainmenu.gd` - main menu 
`mainmenu.tscn` - adjusting a menu

`map_builder.gd` - Map generator, creating 4 types of trees and adding materials to it, creating rocks, place in map

`move.gd` - able player to move

`pause_menu.gd` - pause menu
`pause_menu.tscn` - pause menu

`repair_zone.gd` zone

`ui.gd` - player ui
