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

    const map = Map.new(22);
    var state = State.new(&app, &reg, &map);

    // Setup entities
    state.player = setupPlayer(&state);
    _ = setupEnemy(&state);
    setupMap(&state);

    const deubg_color = rl.Color.yellow.alpha(0.5);

    while (state.app.isRunning()) {
        const delta_time = rl.getFrameTime();

        handleAppInput(&state);
        handlePlayerInput(&state);

        move(&state, delta_time);

        systems.beginFrame(null);
        systems.draw(state.reg);
        if (state.app.debug_mode) {
            debugDrawGridPositions(&state, deubg_color);
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

    if (canChangeDirection(state) and canMove(state, movement.next_direction)) {
        movement.direction = movement.next_direction;
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
                .space => comp.Visual.color(rl.Color.black, false),
                .door => comp.Visual.color(rl.Color.ray_white, false),
            };
            const coord = m.Vec2_i32.new(@intCast(col), @intCast(row));
            const pos = state.map.coordToPosition(coord);
            _ = entities.createRenderable(
                state.reg,
                comp.Position{ .x = pos.x(), .y = pos.y() },
                comp.Shape.rectangle(tile_size, tile_size),
                visual,
            );
        }
    }
}

fn setupPlayer(state: *State) entt.Entity {
    const spawn_coord = state.map.player_spawn_coord;
    const position = state.map.coordToPosition(spawn_coord);
    const e = entities.createRenderable(
        state.reg,
        comp.Position.new(position.x(), position.y()),
        comp.Shape.rectangle(state.map.tile_size, state.map.tile_size),
        comp.Visual.stub(),
    );
    state.reg.add(e, comp.GridPosition.new(spawn_coord.x(), spawn_coord.y()));
    state.reg.add(e, comp.Movement.new(.right));
    state.reg.add(e, comp.Speed.uniform(100));
    return e;
}

fn setupEnemy(state: *State) entt.Entity {
    const spawn_coord = m.Vec2_i32.new(1, 1);
    const position = state.map.coordToPosition(spawn_coord);
    const e = entities.createRenderable(
        state.reg,
        comp.Position.new(position.x(), position.y()),
        comp.Shape.rectangle(state.map.tile_size, state.map.tile_size),
        comp.Visual.stub(),
    );
    state.reg.add(e, comp.GridPosition.new(spawn_coord.x(), spawn_coord.y()));
    state.reg.add(e, comp.Movement.new(.down));
    state.reg.add(e, comp.Speed.uniform(25));
    return e;
}

/// TODO:
/// Make sure, the entity can change direction even if not currently on a tile,
/// if the intended movement is on the same axis as the current direction.
fn canChangeDirection(state: *State) bool {
    const position = state.reg.getConst(comp.Position, state.player);
    const pos = m.Vec2.new(position.x, position.y);
    const coord = state.map.positionToCoord(pos);
    const tile_pos = state.map.coordToPosition(coord);
    return pos.eql(tile_pos);
}

fn canMove(state: *State, direction: comp.Direction) bool {
    const grid_position = state.reg.getConst(comp.GridPosition, state.player);
    const direction_vec = direction.toVec2();
    const target_grid_position = m.Vec2_i32
        .new(grid_position.x, grid_position.y)
        .add(m.Vec2_i32.new(@intFromFloat(direction_vec.x()), @intFromFloat(direction_vec.y())));
    return state.map.getTile(target_grid_position) == .space;
}

//------------------------------------------------------------------------------
// Movement
//------------------------------------------------------------------------------

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
    const direction_vec_i32 = m.Vec2_i32.new(
        @intFromFloat(direction_vec.x()),
        @intFromFloat(direction_vec.y()),
    );
    const target_tile_coord = m.Vec2_i32
        .new(grid_position.x, grid_position.y)
        .add(direction_vec_i32);

    if (state.map.getTile(target_tile_coord) == .space) {
        const pos_offset = m.Vec2
            .new(speed.x, speed.y)
            .scale(delta_time)
            .mul(direction_vec);
        const target_pos = m.Vec2.new(position.x, position.y).add(pos_offset);
        const target_tile_pos = state.map.coordToPosition(target_tile_coord);

        // Get distance from target position after movement to the actual
        // position of the target tile.
        const distance = target_tile_pos.sub(target_pos);
        const distance_mask = distance.mul(direction_vec);

        // Get the corrected target position considering the actual position of
        // the target tile.
        // If the entities target position (= position after movement) is beyond
        // or exactly at the position of the target tile, snap the the entities
        // target position back to the tile position. Use the entites target
        // position otherwise, because in this case, the entity has not yet
        // reached the target tile.
        var corrected_target_pos = target_pos;
        if ((direction_vec.x() != 0 and distance_mask.x() <= 0) or
            (direction_vec.y() != 0 and distance_mask.y() <= 0))
        {
            corrected_target_pos = target_pos.add(distance);
            // Update the entities grid position, if the reached the position of
            // the target tile.
            const grid_position_vec = m.Vec2_i32
                .new(grid_position.x, grid_position.y)
                .add(direction_vec_i32);
            grid_position.x = grid_position_vec.x();
            grid_position.y = grid_position_vec.y();
        }

        // Update entity position.
        position.x = corrected_target_pos.x();
        position.y = corrected_target_pos.y();
    }
}

//------------------------------------------------------------------------------
// Debugging
//------------------------------------------------------------------------------

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
