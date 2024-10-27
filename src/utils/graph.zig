const std = @import("std");
const zig_graph = @import("zig-graph");
const Slice = @import("slice.zig");
const DirectedGraph = zig_graph.DirectedGraph;

pub usingnamespace zig_graph;

const DijkstraNode = struct {
    distance: u64,
    predecessor: ?u64,
};

const DijkstraNodePriorityQueue = struct {
    const Self = @This();

    const DijkstraGraphNodeDistance = struct {
        id: u64,
        distance: u64,
    };

    fn lessThan(
        _: void,
        a: DijkstraGraphNodeDistance,
        b: DijkstraGraphNodeDistance,
    ) std.math.Order {
        return std.math.order(a.distance, b.distance);
    }

    const PriorityQueueType = std.PriorityQueue(
        DijkstraGraphNodeDistance,
        void,
        lessThan,
    );

    queue: PriorityQueueType,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .queue = PriorityQueueType.init(allocator, {}) };
    }

    pub fn deinit(self: *Self) void {
        self.queue.deinit();
    }
};

/// Performs the Dijkstra's shortest path algorithm on a `DirectedGraph`
/// instance.
pub fn dijkstra(
    comptime T: type,
    comptime Context: type,
    allocator: std.mem.Allocator,
    graph: *DirectedGraph(T, Context),
    source: T,
    target: T,
) ![]T {
    const source_id = graph.ctx.hash(source);
    const target_id = graph.ctx.hash(target);

    if (!graph.values.contains(source_id)) {
        @panic("Source does not exist in graph");
    }
    if (!graph.values.contains(target_id)) {
        @panic("Target does not exist in graph");
    }

    var nodes = std.AutoHashMap(u64, DijkstraNode).init(allocator);
    defer nodes.deinit();

    // Initialize nodes.
    var vertex_it = graph.values.iterator();
    while (vertex_it.next()) |vertex| {
        try nodes.put(
            vertex.key_ptr.*,
            .{ .distance = std.math.maxInt(u64), .predecessor = null },
        );
    }

    nodes.getPtr(source_id).?.distance = 0;

    var unvisited = DijkstraNodePriorityQueue.init(allocator);
    defer unvisited.deinit();
    try unvisited.queue.add(.{ .id = source_id, .distance = 0 });

    while (unvisited.queue.removeOrNull()) |node| {
        // Stop, if target is reached.
        if (node.id == target_id) {
            break;
        }

        const current_distance = nodes.getPtr(node.id).?.distance;
        // Iterate adjacent nodes.
        const neighbors_map: *std.AutoHashMap(u64, u64) = graph.adjOut.getPtr(node.id).?;
        var neighbors_it = neighbors_map.keyIterator();
        while (neighbors_it.next()) |neighbor| {
            const edge_distance = graph.getEdge(
                graph.lookup(node.id).?,
                graph.lookup(neighbor.*).?,
            ).?;
            const new_distance = current_distance + edge_distance;
            const neighbor_node = nodes.getPtr(neighbor.*).?;
            if (new_distance < neighbor_node.distance) {
                neighbor_node.distance = new_distance;
                neighbor_node.predecessor = node.id;
                try unvisited.queue.add(.{
                    .id = neighbor.*,
                    .distance = new_distance,
                });
            }
        }
    }

    // Reconstruct path to source by traversing predecessor nodes.
    var path = std.ArrayList(T).init(allocator);
    defer path.deinit();
    var current_id: ?u64 = target_id;
    while (current_id) |current| {
        const val = graph.lookup(current).?;
        try path.append(val);
        current_id = nodes.get(current).?.predecessor;
    }

    // Reverse path slice to return path elements in correct order
    // (source -> target).
    const slice = try path.toOwnedSlice();
    Slice.reverse(T, slice);
    return slice;
}
