const std = @import("std");
const m = @import("math");
const DirectedGraph = @import("utils/graph.zig").DirectedGraph;

pub const MapTileType = enum {
    wall,
    space,
    door,
};

const MapGraphContext = struct {
    const Self = @This();
    pub fn hash(_: Self, key: m.Vec2_i32) u64 {
        return @as(u64, @intCast(key.x())) << 32 | @as(u64, @intCast(key.y()));
    }
    pub fn eql(_: Self, key1: m.Vec2_i32, key2: m.Vec2_i32) bool {
        return key1.eql(key2);
    }
};
const MapGraph = DirectedGraph(m.Vec2_i32, MapGraphContext);

pub const Map = struct {
    const Self = @This();

    tile_size: f32,
    rows: i32,
    cols: i32,
    data: [MAP_ROWS][MAP_COLS]MapTileType,
    graph: MapGraph,
    player_spawn_coord: m.Vec2_i32,

    pub fn init(allocator: std.mem.Allocator, tile_size: f32) Self {
        return Self{
            .tile_size = tile_size,
            .rows = MAP_ROWS,
            .cols = MAP_COLS,
            .data = MAP_DEFAULT_DATA,
            .graph = MapGraph.init(allocator),
            .player_spawn_coord = m.Vec2_i32.new(10, 15),
        };
    }

    pub fn deinit(self: *Self) void {
        self.graph.deinit();
    }

    pub fn setup(self: *Self) !void {
        for (self.data, 0..) |row, index_y| {
            const y: i32 = @intCast(index_y);
            for (row, 0..) |tile, index_x| {
                const x: i32 = @intCast(index_x);
                if (tile == .space) {
                    const current = m.Vec2_i32.new(x, y);
                    try self.graph.add(current);
                    const previous_x = m.Vec2_i32.new(x - 1, y);
                    if (x > 0 and self.graph.contains(previous_x)) {
                        try self.graph.addEdge(previous_x, current, 1);
                        try self.graph.addEdge(current, previous_x, 1);
                    }
                    const previous_y = m.Vec2_i32.new(x, y - 1);
                    if (y > 0 and self.graph.contains(previous_y)) {
                        try self.graph.addEdge(previous_y, current, 1);
                        try self.graph.addEdge(current, previous_y, 1);
                    }
                }
            }
        }
    }

    pub fn coordToPosition(self: *const Self, coord: m.Vec2_i32) m.Vec2 {
        return m.Vec2.new(
            @as(f32, @floatFromInt(coord.x())) * self.tile_size,
            @as(f32, @floatFromInt(coord.y())) * self.tile_size,
        );
    }

    pub fn positionToCoord(self: *const Self, pos: m.Vec2) m.Vec2_i32 {
        return m.Vec2_i32.new(
            @intFromFloat(@divTrunc(pos.x(), self.tile_size)),
            @intFromFloat(@divTrunc(pos.y(), self.tile_size)),
        );
    }

    pub fn sanitizeCoord(self: *const Self, coord: m.Vec2_i32) m.Vec2_i32 {
        const max_x = self.cols - 1;
        const max_y = self.rows - 1;
        var x = coord.x();
        var y = coord.y();
        x = if (x < 0) max_x else if (x > max_x) 0 else x;
        y = if (y < 0) max_y else if (y > max_y) 0 else y;
        return m.Vec2_i32.new(x, y);
    }

    pub fn getTile(self: *const Self, coord: m.Vec2_i32) MapTileType {
        return self.data[@intCast(coord.y())][@intCast(coord.x())];
    }
};

const MAP_ROWS = 27;
const MAP_COLS = 21;
const MAP_DEFAULT_DATA: [MAP_ROWS][MAP_COLS]MapTileType = .{
    // Row 1
    .{ .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall },
    // Row 2
    .{ .wall, .space, .space, .space, .space, .space, .space, .space, .space, .space, .wall, .space, .space, .space, .space, .space, .space, .space, .space, .space, .wall },
    // Row 3
    .{ .wall, .space, .wall, .wall, .wall, .space, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .space, .wall, .wall, .wall, .space, .wall },
    // Row 4
    .{ .wall, .space, .wall, .space, .wall, .space, .wall, .space, .wall, .space, .wall, .space, .wall, .space, .wall, .space, .wall, .space, .wall, .space, .wall },
    // Row 5
    .{ .wall, .space, .wall, .wall, .wall, .space, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .space, .wall, .wall, .wall, .space, .wall },
    // Row 6
    .{ .wall, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .wall },
    // Row 7
    .{ .wall, .space, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .space, .wall },
    // Row 8
    .{ .wall, .space, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .space, .wall },
    // Row 9
    .{ .wall, .space, .space, .space, .space, .space, .wall, .space, .space, .space, .wall, .space, .space, .space, .wall, .space, .space, .space, .space, .space, .wall },
    // Row 10
    .{ .wall, .wall, .wall, .wall, .wall, .space, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .space, .wall, .wall, .wall, .wall, .wall },
    // Row 11
    .{ .space, .space, .space, .space, .wall, .space, .wall, .space, .space, .space, .space, .space, .space, .space, .wall, .space, .wall, .space, .space, .space, .space },
    // Row 12
    .{ .space, .space, .space, .space, .wall, .space, .wall, .space, .wall, .wall, .door, .wall, .wall, .space, .wall, .space, .wall, .space, .space, .space, .space },
    // Row 13
    .{ .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .space, .space, .space, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall },
    // Row 14
    .{ .space, .space, .space, .space, .space, .space, .space, .space, .wall, .space, .space, .space, .wall, .space, .space, .space, .space, .space, .space, .space, .space },
    // Row 15
    .{ .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall },
    // Row 16
    .{ .space, .space, .space, .space, .wall, .space, .wall, .space, .space, .space, .space, .space, .space, .space, .wall, .space, .wall, .space, .space, .space, .space },
    // Row 17
    .{ .space, .space, .space, .space, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .space, .space, .space, .space },
    // Row 18
    .{ .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall },
    // Row 19
    .{ .wall, .space, .space, .space, .space, .space, .space, .space, .space, .space, .wall, .space, .space, .space, .space, .space, .space, .space, .space, .space, .wall },
    // Row 20
    .{ .wall, .space, .wall, .wall, .wall, .space, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .space, .wall, .wall, .wall, .space, .wall },
    // Row 21
    .{ .wall, .space, .space, .space, .wall, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .wall, .space, .space, .space, .wall },
    // Row 22
    .{ .wall, .wall, .wall, .space, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .space, .wall, .wall, .wall },
    // Row 23
    .{ .wall, .wall, .wall, .space, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .space, .wall, .wall, .wall },
    // Row 24
    .{ .wall, .space, .space, .space, .space, .space, .wall, .space, .space, .space, .wall, .space, .space, .space, .wall, .space, .space, .space, .space, .space, .wall },
    // Row 25
    .{ .wall, .space, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .space, .wall },
    // Row 26
    .{ .wall, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .wall },
    // Row 27
    .{ .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall },
};
