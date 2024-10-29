# zig-pacman

> My implementation of `Pacman` in [zig](https://ziglang.org/) using [raylib](https://github.com/Not-Nik/raylib-zig) and an [ECS](https://github.com/prime31/zig-ecs).

I'm working on this game as part of [The 20 Games Challange](https://20_games_challenge.gitlab.io/). Pacman is [Challange #5](https://20_games_challenge.gitlab.io/challenge/#5).

## Goals

- [ ] Create the Pac-Man maze. Place a score and high score counter above the level, and a life counter below. The maze operates on a grid. There is a tunnel that allows Pac-Man and the ghosts to wrap across the screen, appearing on the other side.
- [ ] Fill the maze with dots and four large dots (Power Pellets). Each cell in the grid will contain a dot or power pellet.
- [ ] Create Pac-Man himself. He should be able to move in four directions through the maze. When Pac-Man collides with a dot, he will eat it, increasing the score.
- [ ] Add four ghosts. They will chase Pac-Man through the level. The ghosts start in a “pen” and are released after enough dots are eaten. Each ghost will cycle between “chase mode” and “scatter mode.” During chase mode, the ghosts will move toward specific cells to give the illusion of teamwork and intelligence.
- [ ] Red ghost “Blinky” will target Pac-Man directly.
- [ ] Pink ghost “Pinky” will try to get 4 tiles in front of Pac-Man.
- [ ] Blue ghost “Inky” will target a special position. Draw a line from Blinky’s position to the cell two tiles in front of Pac-Man, then double the length of the line. That is Inky’s target position.
- [ ] Orange ghost “Clyde” will target Pac-Man directly, but will scatter whenever he gets within an 8 tile radius of Pac-Man.
- [ ] Each ghost has an assigned corner that it will scatter to during scatter mode.
- [ ] For more details on the Pac-Man AI, check out this detailed breakdown. If you are using a modern game engine, then you will probably solve some problems (such as pathfinding) differently and will therefore have to improvise a little.
- [ ] Add the “power pellet” mode. When Pac-man eats the pellet, the ghosts will turn blue (scared), and will scatter. Pac-Man can eat the ghosts. After a timer elapses, the ghosts will flash white, then return to normal. Eaten ghosts will award points, turn into eyes, and then return to the pen before coming back as regular ghosts.
- [ ] Add the win states and lose states. Pac-Man will die when eaten by a ghost, consuming a life. When all dots are consumed, the level will reset.

## Running the game

```sh
zig build run
```

## Controls

| Key | Description |
| - | - |
| `K`, `Arrow Up` | Move up |
| `J`, `Arrow Down` | Move down |
| `H`, `Arrow Left` | Move left |
| `L`, `Arrow Right` | Move right |
| `F1` | Toggle debug mode |

## Assets

List of all assets used in this game:

| File | Source/Author |
| - | - |
| | |

