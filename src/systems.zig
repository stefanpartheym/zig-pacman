const rl = @import("raylib");
const entt = @import("entt");

const comp = @import("components.zig");
const Rect = @import("math.zig").Rect;

pub fn beginFrame() void {
    rl.beginDrawing();
    rl.clearBackground(rl.Color.black);
}

pub fn endFrame() void {
    rl.endDrawing();
}

/// Render debug information and entity shape AABB's.
pub fn renderDebug(reg: *entt.Registry) void {
    rl.drawFPS(10, 10);
    var view = reg.view(.{ comp.Position, comp.Shape, comp.Visual }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var pos = view.getConst(comp.Position, entity);
        const shape = view.getConst(comp.Shape, entity);
        if (shape == .circle) {
            pos.x -= shape.getWidth() / 2;
            pos.y -= shape.getHeight() / 2;
        }
        renderEntity(
            pos,
            comp.Shape.rectangle(shape.getWidth(), shape.getHeight()),
            comp.Visual.color(rl.Color.yellow, true),
        );
    }
}

pub fn renderEntities(reg: *entt.Registry) void {
    var view = reg.view(.{ comp.Position, comp.Shape, comp.Visual }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const pos = view.getConst(comp.Position, entity);
        const shape = view.getConst(comp.Shape, entity);
        const visual = view.getConst(comp.Visual, entity);
        renderEntity(pos, shape, visual);
    }
}

fn renderEntity(pos: comp.Position, shape: comp.Shape, visual: comp.Visual) void {
    switch (visual) {
        .stub => renderStub(pos, shape),
        .color => renderShape(pos, shape, visual.color.value, visual.color.outline),
        .sprite => renderSprite(
            .{
                .x = pos.x,
                .y = pos.y,
                .width = shape.getWidth(),
                .height = shape.getHeight(),
            },
            visual.sprite.rect,
            visual.sprite.texture.*,
        ),
        .animation => {
            var anim = visual.animation.playing_animation;
            const frame = anim.getCurrentFrame();
            const frames: f32 = @floatFromInt(visual.animation.playing_animation.animation.frames.len);
            const texture_width = @as(f32, @floatFromInt(visual.animation.texture.width));
            const texture_height = @as(f32, @floatFromInt(visual.animation.texture.height));
            const source_rect = Rect{
                .x = texture_width * frame.region.u * texture_width / frames,
                .y = texture_height * frame.region.v * texture_height / frames,
                .width = texture_width / frames,
                .height = texture_height,
            };
            renderSprite(
                .{
                    .x = pos.x,
                    .y = pos.y,
                    .width = shape.getWidth(),
                    .height = shape.getHeight(),
                },
                source_rect,
                visual.animation.texture.*,
            );
        },
    }
}

fn renderTextCentered(
    text: [*:0]const u8,
    size: i32,
    color: rl.Color,
    display_width: i32,
    display_height: i32,
) void {
    const text_width: f32 = @floatFromInt(rl.measureText(text, size));
    rl.drawText(
        text,
        @divTrunc(display_width, 2) - @divTrunc(text_width, 2),
        @divTrunc(display_height, 2) - @divTrunc(size, 2),
        size,
        color,
    );
}

/// Render a stub shape.
/// TODO: Make visual appearance more noticeable.
fn renderStub(pos: comp.Position, shape: comp.Shape) void {
    renderShape(pos, shape, rl.Color.magenta, false);
}

/// Render a sprite.
fn renderSprite(target: Rect, source: Rect, texture: rl.Texture) void {
    texture.drawPro(
        .{
            .x = source.x,
            .y = source.y,
            .width = source.width,
            .height = source.height,
        },
        .{
            .x = target.x,
            .y = target.y,
            .width = target.width,
            .height = target.height,
        },
        .{ .x = 0, .y = 0 },
        0,
        rl.Color.white,
    );
}

/// Generic rendering function to be used for `stub` and `color` visuals.
fn renderShape(pos: comp.Position, shape: comp.Shape, color: rl.Color, outline: bool) void {
    const p = .{ .x = pos.x, .y = pos.y };
    switch (shape) {
        .triangle => {
            const v1 = .{
                .x = p.x + shape.triangle.v1[0],
                .y = p.y + shape.triangle.v1[1],
            };
            const v2 = .{
                .x = p.x + shape.triangle.v2[0],
                .y = p.y + shape.triangle.v2[1],
            };
            const v3 = .{
                .x = p.x + shape.triangle.v3[0],
                .y = p.y + shape.triangle.v3[1],
            };
            if (outline) {
                rl.drawTriangleLines(v1, v2, v3, color);
            } else {
                rl.drawTriangle(v1, v2, v3, color);
            }
        },
        .rectangle => {
            const size = .{ .x = shape.rectangle.width, .y = shape.rectangle.height };
            if (outline) {
                // NOTE: The `drawRectangleLines` function draws the outlined
                // rectangle incorrectly. Hence, drawing the lines individually.
                const v1 = .{ .x = p.x, .y = p.y };
                const v2 = .{ .x = p.x + size.x, .y = p.y };
                const v3 = .{ .x = p.x + size.x, .y = p.y + size.y };
                const v4 = .{ .x = p.x, .y = p.y + size.y };
                rl.drawLineV(v1, v2, color);
                rl.drawLineV(v2, v3, color);
                rl.drawLineV(v3, v4, color);
                rl.drawLineV(v4, v1, color);
            } else {
                rl.drawRectangleV(p, size, color);
            }
        },
        .circle => {
            if (outline) {
                rl.drawCircleLinesV(p, shape.circle.radius, color);
            } else {
                rl.drawCircleV(p, shape.circle.radius, color);
            }
        },
    }
}
