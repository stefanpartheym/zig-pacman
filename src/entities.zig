//! This file provides common entity factories.
const entt = @import("entt");
const comp = @import("components.zig");

/// Create a renderable entity.
pub fn createRenderable(
    reg: *entt.Registry,
    position: comp.Position,
    shape: comp.Shape,
    visual: comp.Visual,
) entt.Entity {
    const e = reg.create();
    reg.add(e, position);
    reg.add(e, shape);
    reg.add(e, visual);
    return e;
}
