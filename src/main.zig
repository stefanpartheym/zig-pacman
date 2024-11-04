const std = @import("std");
const rl = @import("raylib");
const entt = @import("entt");

const m = @import("math");
const Paa = @import("paa.zig");
const Application = @import("application.zig").Application;
const State = @import("state.zig").State;
const Map = @import("map.zig").Map;
const graph = @import("utils/graph.zig");
const comp = @import("components.zig");
const systems = @import("systems.zig");
const entities = @import("entities.zig");

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

    var map = Map.init(paa.allocator(), 22);
    defer map.deinit();
    try map.setup();

    var state = State.new(&app, &reg, &map);

    // Setup entities
    state.player = setupPlayer(&state);
    state.enemies[0] = setupEnemy(&state, .blinky, m.Vec2_i32.new(10, 10));
    state.enemies[1] = setupEnemy(&state, .inky, m.Vec2_i32.new(9, 12));
    state.enemies[2] = setupEnemy(&state, .pinky, m.Vec2_i32.new(10, 12));
    state.enemies[3] = setupEnemy(&state, .clyde, m.Vec2_i32.new(11, 12));
    setupMap(&state);

    const deubg_color = rl.Color.yellow.alpha(0.5);

    while (state.app.isRunning()) {
        const delta_time = rl.getFrameTime();

        handleAppInput(&state);
        handlePlayerInput(&state);
        try updateEnemies(paa.allocator(), &state);
        updateDirection(&state);

        move(&state, delta_time);
        playerPickupItem(&state);

        systems.beginFrame(null);
        systems.draw(state.reg);
        try drawHud(&state);
        if (state.app.debug_mode) {
            debugDrawGridPositions(&state, deubg_color);
            try debugDrawMapGraph(state.map, rl.Color.red);
            try debugDrawEnemyPath(paa.allocator(), &state);
            systems.drawDebug(state.reg, deubg_color);
        }
        systems.endFrame();
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
}

fn handlePlayerInput(state: *State) void {
    const movement = state.reg.get(comp.Movement, state.player);

    if (rl.isKeyDown(rl.KeyboardKey.key_h)) {
        movement.next_direction = .left;
    } else if (rl.isKeyDown(rl.KeyboardKey.key_l)) {
        movement.next_direction = .right;
    } else if (rl.isKeyDown(rl.KeyboardKey.key_k)) {
        movement.next_direction = .up;
    } else if (rl.isKeyDown(rl.KeyboardKey.key_j)) {
        movement.next_direction = .down;
    }
}

//------------------------------------------------------------------------------
// Entities
//------------------------------------------------------------------------------

fn setupMap(state: *State) void {
    const tile_size = state.map.tile_size;
    for (state.map.data, 0..) |tiles, row| {
        for (tiles, 0..) |tile, col| {
            const visual = switch (tile) {
                .wall => comp.Visual.color(rl.Color.blue, false),
                .space, .blank, .exclusive => comp.Visual.color(rl.Color.black, false),
                .door => comp.Visual.color(rl.Color.ray_white, false),
            };
            const coord = m.Vec2_i32.new(@intCast(col), @intCast(row));
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
            } else {
                state.map.setItem(coord, null);
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

fn setupEnemy(state: *State, enemy_type: comp.EnemyType, spawn_coord: m.Vec2_i32) entt.Entity {
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
    state.reg.add(e, comp.GridPosition.new(spawn_coord.x(), spawn_coord.y()));
    state.reg.add(e, comp.Speed.uniform(100));
    state.reg.add(e, comp.Enemy.new(enemy_type));
    return e;
}

//------------------------------------------------------------------------------
// Update
//------------------------------------------------------------------------------

pub fn updateScore(state: *State, item_type: Map.MapItemType) void {
    state.pallets_eaten += 1;
    const value: u32 = switch (item_type) {
        .pallet => 10,
        .power_pallet => 100,
    };
    state.score += value;

    switch (state.pallets_eaten) {
        // Make the first enemy move after the player consumes the first pallet.
        1 => state.reg.add(state.enemies[0], comp.Movement.new(.none)),
        // Release the other enemies after the player consumed 20 pallets.
        20 => {
            for (state.enemies[1..]) |e| {
                state.reg.add(e, comp.Movement.new(.none));
            }
        },
        else => {},
    }
}

fn updateDirection(state: *State) void {
    const reg = state.reg;
    var view = reg.view(.{ comp.Movement, comp.Position, comp.GridPosition }, .{});
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

fn updateEnemies(allocator: std.mem.Allocator, state: *State) !void {
    var view = state.reg.view(.{ comp.Enemy, comp.Movement, comp.Position, comp.GridPosition }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const movement = state.reg.get(comp.Movement, entity);
        const path = try getEnemyTargetPath(allocator, state, entity);
        defer allocator.free(path);

        if (path.len > 1) {
            // Skip first element in path, as it is the current position of the
            // entity.
            var next_pos = path[1];
            const offset = next_pos.sub(path[0]);
            if (offset.x() > 0) {
                movement.next_direction = .right;
            } else if (offset.x() < 0) {
                movement.next_direction = .left;
            } else if (offset.y() > 0) {
                movement.next_direction = .down;
            } else if (offset.y() < 0) {
                movement.next_direction = .up;
            }
        } else {
            movement.next_direction = .none;
        }
    }
}

fn playerPickupItem(state: *State) void {
    const grid_position = state.reg.get(comp.GridPosition, state.player);
    const coord = m.Vec2_i32.new(grid_position.x, grid_position.y);
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
        // or exactly at the position of the target tile, snap the the entities
        // target position back to the tile position. Use the entites target
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

fn getCoordAheadOf(
    state: *State,
    ref_coord: m.Vec2_i32,
    ref_movement: comp.Movement,
    tiles: i32,
) m.Vec2_i32 {
    const directions = [2]m.Vec2_i32{
        ref_movement.direction.toVec2().cast(i32),
        ref_movement.next_direction.toVec2().cast(i32),
    };
    var direction_idx: usize = 0;
    var current_target = ref_coord;
    var i: usize = 0;
    while (i < tiles) {
        const new_target_pos = state.map.sanitizeCoord(
            current_target.add(directions[direction_idx]),
        );
        if (state.map.graph.contains(new_target_pos)) {
            current_target = new_target_pos;
            i += 1;
        } else if (direction_idx < directions.len - 1) {
            direction_idx += 1;
        } else {
            break;
        }
    }
    return current_target;
}

fn getEnemyTargetPath(allocator: std.mem.Allocator, state: *State, entity: entt.Entity) ![]m.Vec2_i32 {
    const player_grid_position = state.reg.getConst(comp.GridPosition, state.player);
    const player_coord = m.Vec2_i32.new(player_grid_position.x, player_grid_position.y);
    const player_movement = state.reg.getConst(comp.Movement, state.player);

    const enemy = state.reg.getConst(comp.Enemy, entity);
    const grid_position = state.reg.getConst(comp.GridPosition, entity);
    const current_coord = m.Vec2_i32.new(grid_position.x, grid_position.y);

    const target_coord =
        switch (enemy.type) {
        // Ghost pinky tries to get 4 tiles ahead of the player.
        .pinky => getCoordAheadOf(state, player_coord, player_movement, 4),
        .inky => getCoordAheadOf(state, player_coord, player_movement, 2),
        else => player_coord,
    };

    return try graph.dijkstra(
        m.Vec2_i32,
        @TypeOf(state.map.graph.ctx),
        allocator,
        &state.map.graph,
        current_coord,
        target_coord,
    );
}

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

fn drawHud(state: *State) !void {
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
}

/// Draws an entities grid positions in debug mode.
fn debugDrawGridPositions(state: *State, color: rl.Color) void {
    const reg = state.reg;
    const tile_size = state.map.tile_size;
    var view = reg.view(.{comp.GridPosition}, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const grid_pos = reg.getConst(comp.GridPosition, entity);
        const screen_pos = state.map.coordToPosition(m.Vec2_i32.new(grid_pos.x, grid_pos.y));
        systems.drawShape(
            comp.Position.new(screen_pos.x(), screen_pos.y()),
            comp.Shape.rectangle(tile_size, tile_size),
            color,
            false,
        );
    }
}

fn debugDrawMapGraph(map: *Map, color: rl.Color) !void {
    var it = map.graph.adjOut.iterator();
    while (it.next()) |entry| {
        const source_hash = entry.key_ptr.*;
        const targets: std.hash_map.AutoHashMap(u64, u64) = entry.value_ptr.*;
        if (map.graph.lookup(source_hash)) |source| {
            const pos = map.coordToPosition(source).add(m.Vec2.new(map.tile_size / 2, map.tile_size / 2));
            systems.drawShape(comp.Position.new(pos.x(), pos.y()), comp.Shape.circle(5), color, true);
            var targets_it = targets.iterator();
            while (targets_it.next()) |target_entry| {
                if (map.graph.lookup(target_entry.key_ptr.*)) |target| {
                    const target_pos = map.coordToPosition(target).add(m.Vec2.new(map.tile_size / 2, map.tile_size / 2));
                    rl.drawLine(
                        @intFromFloat(pos.x()),
                        @intFromFloat(pos.y()),
                        @intFromFloat(target_pos.x()),
                        @intFromFloat(target_pos.y()),
                        color,
                    );
                }
            }
        }
    }
}

fn debugDrawEnemyPath(allocator: std.mem.Allocator, state: *State) !void {
    const reg = state.reg;
    var view = reg.view(.{ comp.Enemy, comp.GridPosition }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const visual = reg.getConst(comp.Visual, entity);
        const path = try getEnemyTargetPath(allocator, state, entity);
        defer allocator.free(path);
        var previous_coord: ?m.Vec2_i32 = null;
        for (path) |coord| {
            if (previous_coord) |prev_coord| {
                const offset = m.Vec2.new(state.map.tile_size / 2, state.map.tile_size / 2);
                const previous_pos = state.map.coordToPosition(prev_coord).add(offset);
                const current_pos = state.map.coordToPosition(coord).add(offset);
                rl.drawLineEx(
                    .{ .x = previous_pos.x(), .y = previous_pos.y() },
                    .{ .x = current_pos.x(), .y = current_pos.y() },
                    3,
                    visual.color.value,
                );
            }
            previous_coord = coord;
        }
    }
}
