const std = @import("std");
const rl = @import("raylib");
const entt = @import("entt");

const m = @import("math");
const Paa = @import("paa.zig");
const Application = @import("application.zig").Application;
const State = @import("state.zig").State;
const Map = @import("map.zig").Map;
const comp = @import("components.zig");
const systems = @import("systems.zig");
const entities = @import("entities.zig");
const grahpics = @import("graphics");

pub fn main() !void {
    var paa = Paa.init();
    defer paa.deinit();

    var app = Application.init(
        paa.allocator(),
        .{
            .title = "zig-pacman",
            .display = .{
                .width = 800,
                .height = 600,
                .high_dpi = true,
                .target_fps = 60,
            },
        },
    );
    defer app.deinit();

    var reg = entt.Registry.init(paa.allocator());
    defer reg.deinit();

    app.start();
    defer app.stop();

    var map = Map.new(22);
    var state = State.new(&app, &reg, &map);

    // Setup entities
    state.player = setupPlayer(&state);
    state.enemies[0] = setupEnemy(&state, .blinky, .scatter, m.Vec2_i32.new(10, 10));
    state.enemies[1] = setupEnemy(&state, .inky, .house, m.Vec2_i32.new(9, 12));
    state.enemies[2] = setupEnemy(&state, .pinky, .house, m.Vec2_i32.new(10, 12));
    state.enemies[3] = setupEnemy(&state, .clyde, .house, m.Vec2_i32.new(11, 12));

    reset(&state, true);

    const deubg_color = rl.Color.yellow.alpha(0.5);

    while (state.app.isRunning()) {
        const delta_time = rl.getFrameTime();

        handleAppInput(&state);

        if (state.isPlaying()) {
            handlePlayerInput(&state);
            updatePlayerDirection(&state);

            updateEnemyState(&state, delta_time);
            updateEnemyTarget(&state);
            updateEnemies(&state);

            move(&state, delta_time);
        }

        systems.beginFrame(null);
        systems.draw(state.reg);
        try drawUi(&state);
        if (state.app.debug_mode) {
            debugDrawGridPositions(&state, deubg_color);
            debugDrawEnemyTarget(&state);
            systems.drawDebug(state.reg, deubg_color);
        }
        systems.endFrame();

        if (state.isPlaying()) {
            handleCollision(&state);
            playerPickupItem(&state);
        }
    }
}

//------------------------------------------------------------------------------
// Game
//------------------------------------------------------------------------------

fn reset(state: *State, map: bool) void {
    const reg = state.reg;

    // Setup player
    {
        const spawn_coord = state.map.player_spawn_coord;
        const spawn_pos = state.map.coordToPosition(spawn_coord);
        var pos = reg.get(comp.Position, state.player);
        pos.x = spawn_pos.x();
        pos.y = spawn_pos.y();
        var grid_pos = reg.get(comp.GridPosition, state.player);
        grid_pos.x = spawn_coord.x();
        grid_pos.y = spawn_coord.y();
    }

    // Setup enemies
    {
        const EnemyData = struct {
            type: comp.EnemyType,
            state: comp.EnemyState,
            spawn_coord: m.Vec2_i32,
        };
        const data = [4]EnemyData{
            .{ .type = .blinky, .state = .scatter, .spawn_coord = m.Vec2_i32.new(10, 10) },
            .{ .type = .inky, .state = .house, .spawn_coord = m.Vec2_i32.new(9, 12) },
            .{ .type = .pinky, .state = .house, .spawn_coord = m.Vec2_i32.new(10, 12) },
            .{ .type = .clyde, .state = .house, .spawn_coord = m.Vec2_i32.new(11, 12) },
        };
        for (state.enemies, 0..) |entity, i| {
            var enemy = reg.get(comp.Enemy, entity);
            enemy.type = data[i].type;
            enemy.state = data[i].state;
            const spawn_coord = data[i].spawn_coord;
            const spawn_pos = state.map.coordToPosition(spawn_coord);
            var grid_pos = reg.get(comp.GridPosition, entity);
            grid_pos.x = spawn_coord.x();
            grid_pos.y = spawn_coord.y();
            var pos = reg.get(comp.Position, entity);
            pos.x = spawn_pos.x();
            pos.y = spawn_pos.y();
        }
    }

    if (map) {
        setupMap(state);
    }
}

//------------------------------------------------------------------------------
// Input
//------------------------------------------------------------------------------

fn handleAppInput(state: *State) void {
    if (rl.windowShouldClose() or
        rl.isKeyPressed(rl.KeyboardKey.key_escape) or
        rl.isKeyPressed(rl.KeyboardKey.key_q))
    {
        state.app.shutdown();
    }

    if (rl.isKeyPressed(rl.KeyboardKey.key_f1)) {
        state.app.toggleDebugMode();
    }

    if (rl.isKeyPressed(rl.KeyboardKey.key_enter)) {
        switch (state.status) {
            .playing => state.pause(),
            .ready => {
                state.enemy_state_cooldown.resets = 0;
                state.enemy_state_cooldown.reset();
                state.start();
            },
            .paused => state.start(),
            .lost, .won, .gameover => {
                reset(state, state.status != .lost);
                state.start();
            },
        }
    }
}

fn handlePlayerInput(state: *State) void {
    const movement = state.reg.get(comp.Movement, state.player);

    if (rl.isKeyDown(rl.KeyboardKey.key_left) or rl.isKeyDown(rl.KeyboardKey.key_h)) {
        movement.next_direction = .left;
    } else if (rl.isKeyDown(rl.KeyboardKey.key_right) or rl.isKeyDown(rl.KeyboardKey.key_l)) {
        movement.next_direction = .right;
    } else if (rl.isKeyDown(rl.KeyboardKey.key_up) or rl.isKeyDown(rl.KeyboardKey.key_k)) {
        movement.next_direction = .up;
    } else if (rl.isKeyDown(rl.KeyboardKey.key_down) or rl.isKeyDown(rl.KeyboardKey.key_j)) {
        movement.next_direction = .down;
    }
}

//------------------------------------------------------------------------------
// Entities
//------------------------------------------------------------------------------

fn setupMap(state: *State) void {
    state.max_pallets = 0;
    const tile_size = state.map.tile_size;
    for (state.map.data, 0..) |tiles, row| {
        for (tiles, 0..) |tile, col| {
            const coord = m.Vec2_i32.new(@intCast(col), @intCast(row));
            if (state.map.getItem(coord) == null) {
                const visual = switch (tile) {
                    .wall => comp.Visual.color(rl.Color.blue, false),
                    .space, .blank, .exclusive => comp.Visual.color(rl.Color.black, false),
                    .door => comp.Visual.color(rl.Color.ray_white, false),
                };
                const pos = state.map.coordToPosition(coord);
                _ = entities.createRenderable(
                    state.reg,
                    comp.Position{ .x = pos.x(), .y = pos.y() },
                    comp.Shape.rectangle(tile_size, tile_size),
                    visual,
                    null,
                );

                // Setup items for each tile, that are walkably by the player.
                if (tile == .space and !coord.eql(state.map.player_spawn_coord)) {
                    state.map.setItem(coord, setupItem(state, coord, .pallet));
                    state.max_pallets += 1;
                } else {
                    state.map.setItem(coord, null);
                }
            }
        }
    }
}

fn setupItem(state: *State, coord: m.Vec2_i32, item_type: Map.MapItemType) Map.MapItem {
    const offset = state.map.tile_size / 2;
    const shape = comp.Shape.circle(if (item_type == .power_pallet) 6 else 3);
    const pos = state.map.coordToPosition(coord).add(m.Vec2.new(offset, offset));
    const visual = comp.Visual.color(rl.Color.gold, false);
    const e = entities.createRenderable(
        state.reg,
        comp.Position.new(pos.x(), pos.y()),
        shape,
        visual,
        comp.VisualLayer.new(1),
    );

    return Map.MapItem{
        .item_type = item_type,
        .entity = e,
    };
}

fn setupPlayer(state: *State) entt.Entity {
    const spawn_coord = state.map.player_spawn_coord;
    const position = state.map.coordToPosition(spawn_coord);
    const e = entities.createRenderable(
        state.reg,
        comp.Position.new(position.x(), position.y()),
        comp.Shape.rectangle(state.map.tile_size, state.map.tile_size),
        comp.Visual.color(rl.Color.yellow, false),
        comp.VisualLayer.new(2),
    );
    state.reg.add(e, comp.GridPosition.new(spawn_coord.x(), spawn_coord.y()));
    state.reg.add(e, comp.Movement.new(.none));
    state.reg.add(e, comp.Speed.uniform(100));
    return e;
}

fn setupEnemy(
    state: *State,
    enemy_type: comp.EnemyType,
    enemy_state: comp.EnemyState,
    spawn_coord: m.Vec2_i32,
) entt.Entity {
    const position = state.map.coordToPosition(spawn_coord);
    const color = switch (enemy_type) {
        .blinky => rl.Color.red,
        .pinky => rl.Color.pink,
        .inky => rl.Color.dark_blue,
        .clyde => rl.Color.orange,
    };
    const e = entities.createRenderable(
        state.reg,
        comp.Position.new(position.x(), position.y()),
        comp.Shape.rectangle(state.map.tile_size, state.map.tile_size),
        comp.Visual.color(color, false),
        comp.VisualLayer.new(3),
    );
    state.reg.add(e, comp.Movement.new(.none));
    state.reg.add(e, comp.GridPosition.new(spawn_coord.x(), spawn_coord.y()));
    state.reg.add(e, comp.Speed.uniform(100));
    state.reg.add(e, comp.Enemy.new(enemy_type, enemy_state, spawn_coord));
    return e;
}

//------------------------------------------------------------------------------
// Update
//------------------------------------------------------------------------------

pub fn updateScore(state: *State, item_type: Map.MapItemType) void {
    const value: u32 = switch (item_type) {
        .pallet => 10,
        .power_pallet => 100,
    };
    state.score += value;
    state.pallets_eaten += 1;
    if (state.pallets_eaten == state.max_pallets) {
        state.win();
    }
}

fn updatePlayerDirection(state: *State) void {
    const reg = state.reg;
    var view = reg.view(.{ comp.Movement, comp.Position, comp.GridPosition }, .{comp.Enemy});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const grid_position = reg.getConst(comp.GridPosition, entity);
        const position = reg.getConst(comp.Position, entity);
        const movement = reg.get(comp.Movement, entity);
        if (canChangeDirection(state.map, position) and
            canMove(state, grid_position, movement.next_direction))
        {
            movement.direction = movement.next_direction;
        }
    }
}

fn updateEnemyState(state: *State, delta_time: f32) void {
    // Alternate between scatter and chase states 7 times.
    // Final state is chase state.
    if (state.enemy_state_cooldown.resets < 8) {
        // Handle the alternation between scatter and chase states.
        state.enemy_state_cooldown.update(delta_time);
        if (state.enemy_state_cooldown.ready()) {
            switch (state.enemy_state) {
                .scatter => {
                    state.enemy_state = .chase;
                    state.enemy_state_cooldown.set(20);
                },
                .chase => {
                    state.enemy_state = .scatter;
                    state.enemy_state_cooldown.set(7);
                },
                else => {},
            }
        }
    }

    const reg = state.reg;
    var view = state.reg.view(.{ comp.Enemy, comp.GridPosition, comp.Movement }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var enemy = reg.get(comp.Enemy, entity);
        const grid_pos = reg.getConst(comp.GridPosition, entity);
        var new_state = enemy.state;
        switch (enemy.state) {
            .house => {
                if (delta_time > 4) {
                    new_state = .leave_house;
                } else {
                    const pallet_limit: u32 = switch (enemy.type) {
                        .blinky => 0,
                        .pinky => 7,
                        .inky => 17,
                        .clyde => 32,
                    };
                    if (state.pallets_eaten == pallet_limit) {
                        new_state = .leave_house;
                    }
                }
            },
            .leave_house => {
                if (grid_pos.y == state.map.house_entrance_coord.y()) {
                    new_state = .scatter;
                }
            },
            else => {
                new_state = state.enemy_state;
            },
        }

        var movement = reg.get(comp.Movement, entity);
        // Handle state transitions.
        if (new_state != enemy.state) {
            switch (enemy.state) {
                .leave_house => {
                    // After leaving the house, head to the left.
                    movement.direction = .left;
                    movement.next_direction = .left;
                },
                .scatter, .chase => {
                    // Any transition from scatter and chase mode causes a
                    // reversal of direction.
                    movement.next_direction = movement.direction.reverse();
                },
                else => {},
            }
            enemy.state = new_state;
        }
    }
}

fn updateEnemyTarget(state: *State) void {
    const reg = state.reg;
    const player_grid_pos = reg.getConst(comp.GridPosition, state.player);
    const player_movement = reg.getConst(comp.Movement, state.player);
    const player_coord = player_grid_pos.toVec2_i32();
    const player_dir_vec = player_movement.direction.toVec2().cast(i32);
    var view = state.reg.view(.{comp.Enemy}, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var enemy = reg.get(comp.Enemy, entity);
        switch (enemy.state) {
            .scatter => enemy.target_coord = getEnemeyScatterTarget(enemy.type),
            .chase => {
                switch (enemy.type) {
                    .blinky => enemy.target_coord = player_coord,
                    .pinky => enemy.target_coord = player_coord.add(m.Vec2_i32.new(4, 4)),
                    .inky => {
                        const blinky_grid_pos = reg.getConst(comp.GridPosition, state.enemies[0]);
                        const blinky_pos = blinky_grid_pos.toVec2_i32();
                        const d = player_coord.add(m.Vec2_i32.new(2, 2).mul(player_dir_vec)).sub(blinky_pos);
                        enemy.target_coord = blinky_pos.add(d.mul(m.Vec2_i32.new(2, 2)));
                    },
                    .clyde => {
                        const grid_pos = reg.getConst(comp.GridPosition, entity);
                        if (grid_pos.toVec2_i32().cast(f32).distance(player_coord.cast(f32)) > 8) {
                            enemy.target_coord = player_coord;
                        } else {
                            enemy.target_coord = getEnemeyScatterTarget(.clyde);
                        }
                    },
                }
            },
            .leave_house => {
                enemy.target_coord = state.map.house_entrance_coord;
            },
            else => {},
        }
    }
}

fn getEnemeyScatterTarget(enemy_type: comp.EnemyType) m.Vec2_i32 {
    return switch (enemy_type) {
        .blinky => m.Vec2_i32.new(20, 0),
        .pinky => m.Vec2_i32.new(2, 0),
        .inky => m.Vec2_i32.new(20, 26),
        .clyde => m.Vec2_i32.new(0, 26),
    };
}

fn updateEnemies(state: *State) void {
    var reg = state.reg;
    var view = state.reg.view(.{ comp.Enemy, comp.Movement, comp.Position, comp.GridPosition }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const enemy = reg.getConst(comp.Enemy, entity);
        const grid_pos = reg.getConst(comp.GridPosition, entity);
        const position = reg.getConst(comp.Position, entity);
        var movement = reg.get(comp.Movement, entity);
        if (grid_pos.toVec2_i32().eql(enemy.target_coord)) {
            movement.direction = .none;
            movement.next_direction = .none;
        } else if (canChangeDirection(state.map, position)) {
            movement.direction = if (movement.next_direction == .none)
                movement.direction
            else
                movement.next_direction;

            // Determine next direction
            const direction_vec = movement.direction.toVec2().cast(i32);
            const lookahead_coord = grid_pos.toVec2_i32().add(direction_vec);
            const directions = [_]comp.Direction{ .up, .down, .left, .right };
            var min_dist: i32 = std.math.maxInt(i32);
            for (directions) |new_direction| {
                // Make sure, enemy cannot change direction to the exact
                // opposite of the current direction.
                if (new_direction.reverse() == movement.direction) {
                    continue;
                }
                // Check for red zone, where enemies are not allowed to move up.
                if (state.map.isRedZone(lookahead_coord) and (new_direction == .up)) {
                    continue;
                }
                const test_coord = state.map.clampCoord(lookahead_coord.add(new_direction.toVec2().cast(i32)));
                const target_tile = state.map.getTile(test_coord);
                if (target_tile.isWalkable() and (target_tile != .door or enemy.state == .leave_house)) {
                    const current_dist: i32 = @intFromFloat(test_coord.cast(f32).distance(enemy.target_coord.cast(f32)));
                    if (current_dist < min_dist) {
                        min_dist = current_dist;
                        movement.next_direction = new_direction;
                    }
                }
            }
        }
    }
}

/// Handle player colliding with enemies.
fn handleCollision(state: *State) void {
    const size = state.map.tile_size;
    const player_pos = state.reg.get(comp.Position, state.player);
    const player_rect = rl.Rectangle{
        .x = player_pos.x,
        .y = player_pos.y,
        .width = size,
        .height = size,
    };
    var view = state.reg.view(.{ comp.Enemy, comp.Position }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const enemy_pos = state.reg.get(comp.Position, entity);
        const enemy_rect = rl.Rectangle{
            .x = enemy_pos.x,
            .y = enemy_pos.y,
            .width = size,
            .height = size,
        };
        if (rl.checkCollisionRecs(player_rect, enemy_rect)) {
            state.loose();
        }
    }
}

fn playerPickupItem(state: *State) void {
    const grid_position = state.reg.get(comp.GridPosition, state.player);
    const coord = grid_position.toVec2_i32();
    if (state.map.getItem(coord)) |item| {
        state.map.setItem(coord, null);
        state.reg.destroy(item.entity);
        updateScore(state, item.item_type);
    }
}

fn move(state: *State, delta_time: f32) void {
    var view = state.reg.view(.{ comp.Movement, comp.Speed, comp.Position, comp.GridPosition }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        moveEntity(state, delta_time, entity);
    }
}

fn moveEntity(state: *State, delta_time: f32, entity: entt.Entity) void {
    const reg = state.reg;

    const movement = reg.getConst(comp.Movement, entity);
    const speed = reg.getConst(comp.Speed, entity);
    const position = reg.get(comp.Position, entity);
    const grid_position = reg.get(comp.GridPosition, entity);

    const direction_vec = movement.direction.toVec2();
    const target_tile_coord = state.map.sanitizeCoord(
        m.Vec2_i32
            .new(grid_position.x, grid_position.y)
            .add(direction_vec.cast(i32)),
    );

    const tile = state.map.getTile(target_tile_coord);
    if (tile.isWalkable()) {
        const pos_offset = m.Vec2
            .new(speed.x, speed.y)
            .scale(delta_time)
            .mul(direction_vec);
        const target_pos = m.Vec2.new(position.x, position.y).add(pos_offset);
        const target_tile_pos = state.map.coordToPosition(target_tile_coord);

        // Get distance from target position after movement to the actual
        // position of the target tile.
        const distance = target_tile_pos.sub(target_pos);
        // By masking the distance with the direction, the resulting vector has
        // two benefits:
        // 1. It only contains the distance to the target tile for the direction
        //    in which the entity is currently moving:
        //    - direction is left or right: Y is 0, X contains the distance
        //    - direction is up or down:    X is 0, Y contains the distance
        // 2. The sign (negative or positive) of the relevant value will tell,
        //    if the entity's target position is already beyond the target tile
        //    position or if it's not yet there:
        //    - value is above 0: Entity has not yet reached target tile.
        //    - value is below 0: Entity has exceeded position of target tile.
        const distance_masked = distance.mul(direction_vec);

        // Get the corrected target position considering the actual position of
        // the target tile.
        // If the entities target position (= position after movement) is beyond
        // or exactly at the position of the target tile, snap the entities
        // target position back to the tile position. Use the entities target
        // position otherwise, because in this case, the entity has not yet
        // reached the target tile.
        var corrected_target_pos = target_pos;
        if ((distance_masked.x() + distance_masked.y()) <= 0) {
            corrected_target_pos = target_pos.add(distance);
            // Update the entities grid position, if the reached the position of
            // the target tile.
            const grid_position_vec = state.map.sanitizeCoord(
                m.Vec2_i32
                    .new(grid_position.x, grid_position.y)
                    .add(direction_vec.cast(i32)),
            );
            grid_position.x = grid_position_vec.x();
            grid_position.y = grid_position_vec.y();
        }

        // Update entity position.
        position.x = corrected_target_pos.x();
        position.y = corrected_target_pos.y();
    }
}

//------------------------------------------------------------------------------
// Utitlity
//------------------------------------------------------------------------------

fn canChangeDirection(map: *Map, position: comp.Position) bool {
    const pos = m.Vec2.new(position.x, position.y);
    const coord = map.positionToCoord(pos);
    const tile_pos = map.coordToPosition(coord);
    return pos.eql(tile_pos);
}

fn canMove(state: *State, grid_position: comp.GridPosition, direction: comp.Direction) bool {
    const target_grid_position = m.Vec2_i32
        .new(grid_position.x, grid_position.y)
        .add(direction.toVec2().cast(i32));
    const tile = state.map.getTile(state.map.sanitizeCoord(target_grid_position));
    return tile.isWalkable();
}

//------------------------------------------------------------------------------
// Drawing
//------------------------------------------------------------------------------

fn drawUi(state: *State) !void {
    const color = rl.Color.ray_white;
    const size = 24;
    const tile_size: i32 = @intFromFloat(state.map.tile_size);
    const offset_x = tile_size * state.map.cols + tile_size;
    const offset_y = 10;
    var text_buf: [255]u8 = undefined;

    const score_text = try std.fmt.bufPrintZ(&text_buf, "Score: {d}", .{state.score});
    rl.drawText(
        score_text,
        offset_x,
        offset_y,
        size,
        color,
    );

    const lives_text = try std.fmt.bufPrintZ(&text_buf, "Lives: {d}", .{state.lives});
    rl.drawText(
        lives_text,
        offset_x,
        offset_y * 2 + size,
        size,
        color,
    );

    const offset_y_mid = @as(i32, @intCast(@divTrunc(state.config.display.height, 2))) - size;
    switch (state.status) {
        .ready => {
            rl.drawText(
                "Press [ENTER] to start",
                offset_x,
                offset_y_mid,
                size,
                color,
            );
        },
        .paused => {
            rl.drawText(
                "Press [ENTER] to resume",
                offset_x,
                offset_y_mid,
                size,
                color,
            );
        },
        .lost => {
            rl.drawText(
                "You lost!\nPress [ENTER] to start",
                offset_x,
                offset_y_mid,
                size,
                color,
            );
        },
        .gameover => {
            rl.drawText(
                "GAME OVER!\nPress [ENTER] to restart",
                offset_x,
                offset_y_mid,
                size,
                color,
            );
        },
        .won => {
            rl.drawText(
                "You won!\nPress [ENTER] to restart",
                offset_x,
                offset_y_mid,
                size,
                color,
            );
        },
        else => {},
    }
}

/// Draws an entities grid positions in debug mode.
fn debugDrawGridPositions(state: *State, color: rl.Color) void {
    const reg = state.reg;
    const tile_size = state.map.tile_size;
    var view = reg.view(.{comp.GridPosition}, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const grid_pos = reg.getConst(comp.GridPosition, entity);
        const screen_pos = state.map.coordToPosition(grid_pos.toVec2_i32());
        systems.drawShape(
            comp.Position.new(screen_pos.x(), screen_pos.y()),
            comp.Shape.rectangle(tile_size, tile_size),
            color,
            false,
        );
    }
}

fn debugDrawEnemyTarget(state: *State) void {
    const reg = state.reg;
    var view = reg.view(.{ comp.Enemy, comp.GridPosition, comp.Visual }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const enemy = reg.getConst(comp.Enemy, entity);
        const grid_pos = reg.getConst(comp.GridPosition, entity);
        const visual = reg.getConst(comp.Visual, entity);
        const offset = m.Vec2.new(state.map.tile_size / 2, state.map.tile_size / 2);
        const current_pos = state.map.coordToPosition(grid_pos.toVec2_i32()).add(offset);
        const target_pos = state.map.coordToPosition(state.map.clampCoord(enemy.target_coord)).add(offset);
        rl.drawLineEx(
            .{ .x = current_pos.x(), .y = current_pos.y() },
            .{ .x = target_pos.x(), .y = target_pos.y() },
            3,
            visual.color.value,
        );
        // rl.drawRectangleV(
        //     .{ .x = target_pos_nooffset.x(), .y = target_pos_nooffset.y() },
        //     .{ .x = state.map.tile_size, .y = state.map.tile_size },
        //     visual.color.value.fade(0.5),
        // );
    }
}
