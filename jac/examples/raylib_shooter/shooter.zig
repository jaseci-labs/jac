// Jac Cube Shooter - the Zig twin of shooter.na.jac.
//
// A faithful Zig port of the Jac-native shooter, kept deliberately close so the
// two can be compared side by side. Like the Jac version, it binds raylib by
// declaring its entry points directly - here as `extern fn`, the moral
// equivalent of Jac's `import from raylib { def ... }` block - so no C headers
// are needed; the symbols resolve out of the precompiled libraylib shared
// library at link/load time. Rendering goes through the same scalar `rlgl`
// immediate-mode API (rlVertex3f / rlColor4ub / rlTranslatef / ...) rather than
// raylib's by-value Vector3/Camera3D API, so the on-screen result is identical.
//
// Build/run via `./demo.sh --zig` (which fetches a Zig toolchain if you don't
// already have one).
//
// Controls: mouse / arrows aim (click or Tab to capture the cursor for
// mouse-look), WASD move, Space fire, Tab release / re-capture cursor, Esc quit.

const std = @import("std");

// ── raylib bindings (resolved from libraylib at link time) ──────────────────
// `extern fn` uses the C calling convention by default, so these line up with
// raylib's C ABI without any per-declaration annotation.
extern fn InitWindow(width: c_int, height: c_int, title: [*:0]const u8) void;
extern fn WindowShouldClose() bool;
extern fn CloseWindow() void;
extern fn BeginDrawing() void;
extern fn EndDrawing() void;
extern fn EndMode3D() void;
extern fn DrawFPS(pos_x: c_int, pos_y: c_int) void;
extern fn GetFrameTime() f32;
extern fn IsKeyDown(key: c_int) bool;
extern fn IsKeyPressed(key: c_int) bool;
extern fn GetMouseX() c_int;
extern fn GetMouseY() c_int;
extern fn IsMouseButtonPressed(button: c_int) bool;
extern fn DisableCursor() void;
extern fn EnableCursor() void;
extern fn rlClearColor(r: u8, g: u8, b: u8, a: u8) void;
extern fn rlClearScreenBuffers() void;
extern fn rlEnableDepthTest() void;
extern fn rlMatrixMode(mode: c_int) void;
extern fn rlLoadIdentity() void;
extern fn rlPushMatrix() void;
extern fn rlPopMatrix() void;
extern fn rlTranslatef(x: f32, y: f32, z: f32) void;
extern fn rlRotatef(angle: f32, x: f32, y: f32, z: f32) void;
extern fn rlFrustum(left: f64, right: f64, bottom: f64, top: f64, znear: f64, zfar: f64) void;
extern fn rlOrtho(left: f64, right: f64, bottom: f64, top: f64, znear: f64, zfar: f64) void;
extern fn rlBegin(mode: c_int) void;
extern fn rlEnd() void;
extern fn rlVertex3f(x: f32, y: f32, z: f32) void;
extern fn rlColor4ub(r: u8, g: u8, b: u8, a: u8) void;
extern fn rlSetLineWidth(width: f32) void;
extern fn GetTime() f64;
extern fn FileExists(fileName: [*:0]const u8) bool;
extern fn LoadFileText(fileName: [*:0]const u8) [*:0]const u8;
extern fn TextToInteger(text: [*:0]const u8) c_int;
extern fn SaveFileText(fileName: [*:0]const u8, text: [*:0]const u8) bool;

// raylib's GL matrix-mode and primitive constants (mirrors the Jac globals).
const RL_MODELVIEW: c_int = 0x1700;
const RL_PROJECTION: c_int = 0x1701;
const RL_LINES: c_int = 0x0001;
const RL_TRIANGLES: c_int = 0x0004;

// Saturating-ish channel cast: shade values are clamped to 0..255 by _shade.
inline fn u8c(v: i32) u8 {
    return @intCast(v);
}

// ── thin wrappers, 1:1 with the Jac source ──────────────────────────────────

/// Open a window. No frame-rate cap is set, so the loop runs as fast as the
/// hardware allows (call SetTargetFPS yourself if you want to limit it).
fn open_window(width: c_int, height: c_int, title: [*:0]const u8) void {
    InitWindow(width, height, title);
}

/// True once the user closes the window or presses ESC.
fn should_close() bool {
    return WindowShouldClose();
}

/// Tear the window down.
fn close_window() void {
    CloseWindow();
}

/// Seconds elapsed during the previous frame (for frame-rate-independent motion).
fn dt() f64 {
    return GetFrameTime();
}

/// Held-this-frame test for a raylib key code.
fn key_held(code: c_int) bool {
    return IsKeyDown(code);
}

/// Pressed-this-frame (edge) test for a raylib key code.
fn key_tapped(code: c_int) bool {
    return IsKeyPressed(code);
}

/// Current mouse X in pixels (as a float - matches the Jac float(GetMouseX())).
fn mouse_x() f64 {
    return @floatFromInt(GetMouseX());
}

/// Current mouse Y in pixels (as a float).
fn mouse_y() f64 {
    return @floatFromInt(GetMouseY());
}

/// Pressed-this-frame test for a mouse button (0 = left).
fn mouse_pressed(button: c_int) bool {
    return IsMouseButtonPressed(button);
}

/// Hide and lock the cursor for FPS-style relative mouse-look.
fn lock_mouse() void {
    DisableCursor();
}

/// Show and release the cursor.
fn unlock_mouse() void {
    EnableCursor();
}

/// Begin a frame: clear color+depth to (r,g,b) and turn on depth testing.
fn begin_frame(r: i32, g: i32, b: i32) void {
    BeginDrawing();
    rlClearColor(u8c(r), u8c(g), u8c(b), 255);
    rlClearScreenBuffers();
    rlEnableDepthTest();
}

/// Present the frame.
fn end_frame() void {
    EndDrawing();
}

/// End the 3D pass and switch to a pixel-space 2D overlay mode.
fn end_camera(width: f64, height: f64) void {
    EndMode3D();
    rlMatrixMode(RL_PROJECTION);
    rlLoadIdentity();
    rlOrtho(0.0, width, height, 0.0, -1.0, 1.0);
    rlMatrixMode(RL_MODELVIEW);
    rlLoadIdentity();
}

/// Draw raylib's built-in FPS counter at (x, y) as a 2D overlay.
fn draw_fps(x: c_int, y: c_int) void {
    DrawFPS(x, y);
}

/// Install a perspective camera at (px,py,pz) looking with yaw/pitch (degrees).
fn set_camera(cpx: f32, cpy: f32, cpz: f32, yaw_deg: f32, pitch_deg: f32, aspect: f32) void {
    const near: f64 = 0.05;
    const far_plane: f64 = 400.0;
    const top: f64 = near * 0.57735026;
    const right: f64 = top * @as(f64, aspect);
    rlMatrixMode(RL_PROJECTION);
    rlLoadIdentity();
    rlFrustum(-right, right, -top, top, near, far_plane);
    rlMatrixMode(RL_MODELVIEW);
    rlLoadIdentity();
    rlRotatef(-pitch_deg, 1.0, 0.0, 0.0);
    rlRotatef(-yaw_deg, 0.0, 1.0, 0.0);
    rlTranslatef(-cpx, -cpy, -cpz);
}

/// Emit one quad (corners 0->1->2->3, CCW) as two triangles.
fn _quad(p0: f32, p1: f32, p2: f32, p3: f32, p4: f32, p5: f32, p6: f32, p7: f32, p8: f32, p9: f32, p10: f32, p11: f32) void {
    rlVertex3f(p0, p1, p2);
    rlVertex3f(p3, p4, p5);
    rlVertex3f(p6, p7, p8);
    rlVertex3f(p0, p1, p2);
    rlVertex3f(p6, p7, p8);
    rlVertex3f(p9, p10, p11);
}

/// Scale a 0-255 channel by a percentage (cheap face shading).
fn _shade(c: i32, pct: i32) i32 {
    const v = @divTrunc(c * pct, 100);
    return if (v < 255) v else 255;
}

/// Draw an axis-aligned colored box centered at (cx,cy,cz) with size (sx,sy,sz).
fn draw_box(cx: f32, cy: f32, cz: f32, sx: f32, sy: f32, sz: f32, r: i32, g: i32, b: i32) void {
    const hx = sx * 0.5;
    const hy = sy * 0.5;
    const hz = sz * 0.5;
    rlPushMatrix();
    rlTranslatef(cx, cy, cz);
    rlBegin(RL_TRIANGLES);

    rlColor4ub(u8c(_shade(r, 100)), u8c(_shade(g, 100)), u8c(_shade(b, 100)), 255);
    _quad(-hx, hy, hz, hx, hy, hz, hx, hy, -hz, -hx, hy, -hz);
    rlColor4ub(u8c(_shade(r, 85)), u8c(_shade(g, 85)), u8c(_shade(b, 85)), 255);
    _quad(-hx, -hy, hz, hx, -hy, hz, hx, hy, hz, -hx, hy, hz);
    _quad(hx, -hy, -hz, -hx, -hy, -hz, -hx, hy, -hz, hx, hy, -hz);
    rlColor4ub(u8c(_shade(r, 70)), u8c(_shade(g, 70)), u8c(_shade(b, 70)), 255);
    _quad(hx, -hy, hz, hx, -hy, -hz, hx, hy, -hz, hx, hy, hz);
    _quad(-hx, -hy, -hz, -hx, -hy, hz, -hx, hy, hz, -hx, hy, -hz);
    rlColor4ub(u8c(_shade(r, 45)), u8c(_shade(g, 45)), u8c(_shade(b, 45)), 255);
    _quad(-hx, -hy, -hz, hx, -hy, -hz, hx, -hy, hz, -hx, -hy, hz);

    rlEnd();
    rlPopMatrix();
}

/// Draw a flat floor grid of half*2 lines per axis, spaced step apart, on y=0.
fn draw_floor(half: i32, step: f32) void {
    const ext = @as(f32, @floatFromInt(half)) * step;
    rlSetLineWidth(1.0);
    rlBegin(RL_LINES);
    rlColor4ub(55, 60, 75, 255);
    var i: i32 = -half;
    while (i <= half) : (i += 1) {
        const f = @as(f32, @floatFromInt(i)) * step;
        rlVertex3f(f, 0.0, -ext);
        rlVertex3f(f, 0.0, ext);
        rlVertex3f(-ext, 0.0, f);
        rlVertex3f(ext, 0.0, f);
    }
    rlEnd();
}

/// Benchmark duration in seconds, or 0 for normal (interactive) play.
///
/// `demo.sh` writes the requested duration into a sibling `.bench_seconds` file
/// before launching, then deletes it; when that file is absent (every
/// interactive run, or a bare `./shooter_zig`) this returns 0 and the game loop
/// runs until the window is closed. The whole benchmark path is dormant unless
/// the file exists. Read with raylib's own cross-platform file helpers, exactly
/// as the Jac twin does.
fn bench_seconds() f64 {
    if (FileExists(".bench_seconds")) {
        return @floatFromInt(TextToInteger(LoadFileText(".bench_seconds")));
    }
    return 0.0;
}

/// Hand the benchmark result back to demo.sh. Written to a sibling
/// `.bench_result` file via raylib's SaveFileText (not stdout), exactly as the
/// Jac twin does, so demo.sh reads both builds the same way. Fields are
/// positional: avg_fps max_fps frames seconds.
fn write_bench_result(avg_fps: f64, max_fps: f64, frames: i64, seconds: f64) void {
    var buf: [192]u8 = undefined;
    const s = std.fmt.bufPrintZ(&buf, "BENCH_RESULT {d:.6} {d:.6} {d} {d:.6}", .{ avg_fps, max_fps, frames, seconds }) catch return;
    _ = SaveFileText(".bench_result", s.ptr);
}

// ── key codes & game state (mirrors the Jac globals) ─────────────────────────

const KEY_W: c_int = 87;
const KEY_A: c_int = 65;
const KEY_S: c_int = 83;
const KEY_D: c_int = 68;
const KEY_SPACE: c_int = 32;
const KEY_RIGHT: c_int = 262;
const KEY_LEFT: c_int = 263;
const KEY_DOWN: c_int = 264;
const KEY_UP: c_int = 265;
const KEY_TAB: c_int = 258;
const MOUSE_LEFT: c_int = 0;
const DEG2RAD: f64 = 0.017453292519943295;

var px: f64 = 0.0;
var py: f64 = 2.0;
var pz: f64 = 12.0;
var yaw: f64 = 0.0;
var pitch: f64 = 0.0;
var fire_cd: f64 = 0.0;
var world_t: f64 = 0.0;
var score: i32 = 0;
var rng: i64 = 987654321;
var prev_mx: f64 = 0.0;
var prev_my: f64 = 0.0;
var mouse_warmup: i32 = 12;
var mouse_sens: f64 = 0.12;
var mouse_captured: bool = false;

const Target = struct {
    x: f64,
    y: f64,
    z: f64,
    base_y: f64,
    phase: f64,
    alive: bool,
};

const Bullet = struct {
    x: f64,
    y: f64,
    z: f64,
    vx: f64,
    vy: f64,
    vz: f64,
    life: f64,
};

/// cos via range-reduced Taylor series (good to ~1e-4 on the reduced range).
fn jcos(a_in: f64) f64 {
    const twopi = 6.283185307179586;
    const pi = 3.141592653589793;
    var a = a_in;
    while (a > pi) {
        a -= twopi;
    }
    while (a < -pi) {
        a += twopi;
    }
    const x2 = a * a;
    const x4 = x2 * x2;
    const x6 = x4 * x2;
    const x8 = x4 * x4;
    const x10 = x8 * x2;
    const x12 = x8 * x4;
    return 1.0 - x2 / 2.0 + x4 / 24.0 - x6 / 720.0 + x8 / 40320.0 - x10 / 3628800.0 + x12 / 479001600.0;
}

/// sin(a) = cos(a - pi/2).
fn jsin(a: f64) f64 {
    return jcos(a - 1.5707963267948796);
}

/// Uniform pseudo-random float in [0, 1) via a 31-bit LCG.
fn rand01() f64 {
    rng = @rem(rng * 1103515245 + 12345, 2147483648);
    return @as(f64, @floatFromInt(rng)) / 2147483648.0;
}

/// Random float in [lo, hi).
fn rand_range(lo: f64, hi: f64) f64 {
    return lo + rand01() * (hi - lo);
}

/// (Re)place a target somewhere in the arena in front of the player.
fn respawn(t: *Target) void {
    t.x = rand_range(-14.0, 14.0);
    t.base_y = rand_range(1.0, 5.0);
    t.z = rand_range(-16.0, 2.0);
    t.phase = rand_range(0.0, 6.28);
    t.y = t.base_y;
    t.alive = true;
}

/// Fire a bullet from the eye along the current aim, reusing a dead pool slot.
fn fire(bullets: []Bullet) void {
    const yaw_r = yaw * DEG2RAD;
    const pitch_r = pitch * DEG2RAD;
    const cp = jcos(pitch_r);
    const dx = -jsin(yaw_r) * cp;
    const dy = jsin(pitch_r);
    const dz = -jcos(yaw_r) * cp;
    const speed = 40.0;
    for (bullets) |*b| {
        if (b.life <= 0.0) {
            b.x = px;
            b.y = py;
            b.z = pz;
            b.vx = dx * speed;
            b.vy = dy * speed;
            b.vz = dz * speed;
            b.life = 2.0;
            return;
        }
    }
}

/// Advance bullets, resolve hits against targets, and tally score.
fn update_bullets(bullets: []Bullet, targets: []Target, step: f64) void {
    for (bullets) |*b| {
        if (b.life > 0.0) {
            b.x += b.vx * step;
            b.y += b.vy * step;
            b.z += b.vz * step;
            b.life -= step;
            for (targets) |*t| {
                if (t.alive) {
                    const ddx = b.x - t.x;
                    const ddy = b.y - t.y;
                    const ddz = b.z - t.z;
                    if (ddx * ddx + ddy * ddy + ddz * ddz < 1.4) {
                        t.alive = false;
                        b.life = 0.0;
                        score += 1;
                        respawn(t);
                    }
                }
            }
        }
    }
}

/// Read keyboard + mouse and update camera orientation + position this frame.
fn handle_input(step: f64) void {
    const turn = 90.0 * step;

    if (key_tapped(KEY_TAB)) {
        if (mouse_captured) {
            unlock_mouse();
            mouse_captured = false;
        } else {
            lock_mouse();
            mouse_captured = true;
            mouse_warmup = 8;
        }
    }
    if (!mouse_captured and mouse_pressed(MOUSE_LEFT)) {
        lock_mouse();
        mouse_captured = true;
        mouse_warmup = 8;
    }

    if (key_held(KEY_LEFT)) {
        yaw += turn;
    }
    if (key_held(KEY_RIGHT)) {
        yaw -= turn;
    }
    if (key_held(KEY_UP)) {
        pitch += turn;
    }
    if (key_held(KEY_DOWN)) {
        pitch -= turn;
    }

    if (mouse_captured) {
        const mx = mouse_x();
        const my = mouse_y();
        if (mouse_warmup > 0) {
            mouse_warmup -= 1;
        } else {
            const ddx = mx - prev_mx;
            const ddy = my - prev_my;
            if (ddx < 150.0 and ddx > -150.0 and ddy < 150.0 and ddy > -150.0) {
                yaw -= ddx * mouse_sens;
                pitch -= ddy * mouse_sens;
            }
        }
        prev_mx = mx;
        prev_my = my;
    }

    if (pitch > 85.0) {
        pitch = 85.0;
    }
    if (pitch < -85.0) {
        pitch = -85.0;
    }

    const yaw_r = yaw * DEG2RAD;
    const fwd_x = -jsin(yaw_r);
    const fwd_z = -jcos(yaw_r);
    const rgt_x = jcos(yaw_r);
    const rgt_z = -jsin(yaw_r);
    const move = 8.0 * step;
    if (key_held(KEY_W)) {
        px += fwd_x * move;
        pz += fwd_z * move;
    }
    if (key_held(KEY_S)) {
        px -= fwd_x * move;
        pz -= fwd_z * move;
    }
    if (key_held(KEY_D)) {
        px += rgt_x * move;
        pz += rgt_z * move;
    }
    if (key_held(KEY_A)) {
        px -= rgt_x * move;
        pz -= rgt_z * move;
    }
}

const NUM_TARGETS = 7;
const NUM_BULLETS = 24;

pub fn main() void {
    var targets: [NUM_TARGETS]Target = undefined;
    var bullets: [NUM_BULLETS]Bullet = undefined;

    open_window(960, 600, "Jac Cube Shooter (Zig)");

    for (&targets) |*t| {
        t.* = Target{ .x = 0.0, .y = 0.0, .z = 0.0, .base_y = 0.0, .phase = 0.0, .alive = false };
        respawn(t);
    }

    for (&bullets) |*b| {
        b.* = Bullet{ .x = 0.0, .y = 0.0, .z = 0.0, .vx = 0.0, .vy = 0.0, .vz = 0.0, .life = 0.0 };
    }

    const bench = bench_seconds();
    var frames: i64 = 0;
    var max_fps: f64 = 0.0;

    while (!should_close()) {
        const step = dt();
        world_t += step;

        frames += 1;
        if (step > 0.0) {
            const inst = 1.0 / step;
            if (inst > max_fps) {
                max_fps = inst;
            }
        }

        handle_input(step);
        fire_cd -= step;
        if (key_held(KEY_SPACE) and fire_cd <= 0.0) {
            fire(&bullets);
            fire_cd = 0.14;
        }
        update_bullets(&bullets, &targets, step);

        for (&targets) |*t| {
            t.y = t.base_y + 0.4 * jsin(world_t * 1.5 + t.phase);
        }

        begin_frame(15, 18, 28);
        set_camera(@floatCast(px), @floatCast(py), @floatCast(pz), @floatCast(yaw), @floatCast(pitch), 1.6);
        draw_floor(20, 1.5);

        for (&targets) |*t| {
            if (t.alive) {
                draw_box(@floatCast(t.x), @floatCast(t.y), @floatCast(t.z), 1.4, 1.4, 1.4, 235, 80, 60);
            }
        }

        for (&bullets) |*b| {
            if (b.life > 0.0) {
                draw_box(@floatCast(b.x), @floatCast(b.y), @floatCast(b.z), 0.22, 0.22, 0.22, 250, 220, 90);
            }
        }

        end_camera(960.0, 600.0);
        draw_fps(10, 10);
        end_frame();

        if (bench > 0.0 and GetTime() >= bench) {
            break;
        }
    }

    if (bench > 0.0) {
        const elapsed = GetTime();
        const avg_fps = if (elapsed > 0.0) @as(f64, @floatFromInt(frames)) / elapsed else 0.0;
        write_bench_result(avg_fps, max_fps, frames, elapsed);
    }

    close_window();
}
