// Jac Cube Shooter - the Rust twin of shooter.jac / shooter.zig.
//
// A faithful Rust port of the Zig twin, kept deliberately close so the three
// can be compared side by side. Like the other two, it binds raylib by
// declaring its entry points directly - here as an `extern "C"` block, the
// moral equivalent of Jac's `import from raylib { def ... }` - so no C headers
// and no crates are needed; the symbols resolve out of the precompiled
// libraylib shared library at link/load time. Rendering goes through the same
// scalar `rlgl` immediate-mode API, so the on-screen result is identical.
//
// Build/run via `./demo.sh --rust` (which installs a minimal Rust toolchain
// into .build/ if you don't already have rustc >= 1.85). It is a single-file
// `rustc` build - no cargo, no crates - against the staged libraylib, with an
// `@loader_path` / `$ORIGIN` runpath like the Zig twin.
//
// Controls: mouse / arrows aim (click or Tab to capture the cursor for
// mouse-look), WASD move, Space fire, Tab release / re-capture cursor, Esc quit.

use std::ffi::{c_char, c_int, CStr, CString};

// ── raylib bindings (resolved from libraylib at link time) ──────────────────
// C `bool` is ABI-compatible with Rust `bool`.
#[link(name = "raylib")]
unsafe extern "C" {
    fn InitWindow(width: c_int, height: c_int, title: *const c_char);
    fn WindowShouldClose() -> bool;
    fn CloseWindow();
    fn BeginDrawing();
    fn EndDrawing();
    fn EndMode3D();
    fn DrawFPS(pos_x: c_int, pos_y: c_int);
    fn GetFrameTime() -> f32;
    fn IsKeyDown(key: c_int) -> bool;
    fn IsKeyPressed(key: c_int) -> bool;
    fn GetMouseX() -> c_int;
    fn GetMouseY() -> c_int;
    fn IsMouseButtonPressed(button: c_int) -> bool;
    fn DisableCursor();
    fn EnableCursor();
    fn rlClearColor(r: u8, g: u8, b: u8, a: u8);
    fn rlClearScreenBuffers();
    fn rlEnableDepthTest();
    fn rlMatrixMode(mode: c_int);
    fn rlLoadIdentity();
    fn rlPushMatrix();
    fn rlPopMatrix();
    fn rlTranslatef(x: f32, y: f32, z: f32);
    fn rlRotatef(angle: f32, x: f32, y: f32, z: f32);
    fn rlFrustum(left: f64, right: f64, bottom: f64, top: f64, znear: f64, zfar: f64);
    fn rlOrtho(left: f64, right: f64, bottom: f64, top: f64, znear: f64, zfar: f64);
    fn rlBegin(mode: c_int);
    fn rlEnd();
    fn rlVertex3f(x: f32, y: f32, z: f32);
    fn rlColor4ub(r: u8, g: u8, b: u8, a: u8);
    fn rlSetLineWidth(width: f32);
    fn GetTime() -> f64;
    fn FileExists(file_name: *const c_char) -> bool;
    fn LoadFileText(file_name: *const c_char) -> *const c_char;
    fn TextToInteger(text: *const c_char) -> c_int;
    fn SaveFileText(file_name: *const c_char, text: *const c_char) -> bool;
    fn TakeScreenshot(file_name: *const c_char);
}

// raylib's GL matrix-mode and primitive constants (mirrors the Jac globals).
const RL_MODELVIEW: c_int = 0x1700;
const RL_PROJECTION: c_int = 0x1701;
const RL_LINES: c_int = 0x0001;
const RL_TRIANGLES: c_int = 0x0004;

// Channel cast: shade values are clamped to 0..255 by shade().
#[inline]
fn u8c(v: i32) -> u8 {
    v as u8
}

// ── thin wrappers, 1:1 with the Jac source ──────────────────────────────────

/// Open a window. No frame-rate cap is set, so the loop runs uncapped.
fn open_window(width: c_int, height: c_int, title: &CStr) {
    unsafe { InitWindow(width, height, title.as_ptr()) }
}

/// True once the user closes the window or presses ESC.
fn should_close() -> bool {
    unsafe { WindowShouldClose() }
}

/// Tear the window down.
fn close_window() {
    unsafe { CloseWindow() }
}

/// Seconds elapsed during the previous frame.
fn dt() -> f64 {
    unsafe { GetFrameTime() as f64 }
}

/// Held-this-frame test for a raylib key code.
fn key_held(code: c_int) -> bool {
    unsafe { IsKeyDown(code) }
}

/// Pressed-this-frame (edge) test for a raylib key code.
fn key_tapped(code: c_int) -> bool {
    unsafe { IsKeyPressed(code) }
}

/// Current mouse X in pixels (as a float - matches the Jac float(GetMouseX())).
fn mouse_x() -> f64 {
    unsafe { GetMouseX() as f64 }
}

/// Current mouse Y in pixels (as a float).
fn mouse_y() -> f64 {
    unsafe { GetMouseY() as f64 }
}

/// Pressed-this-frame test for a mouse button (0 = left).
fn mouse_pressed(button: c_int) -> bool {
    unsafe { IsMouseButtonPressed(button) }
}

/// Hide and lock the cursor for FPS-style relative mouse-look.
fn lock_mouse() {
    unsafe { DisableCursor() }
}

/// Show and release the cursor.
fn unlock_mouse() {
    unsafe { EnableCursor() }
}

/// Begin a frame: clear color+depth to (r,g,b) and turn on depth testing.
fn begin_frame(r: i32, g: i32, b: i32) {
    unsafe {
        BeginDrawing();
        rlClearColor(u8c(r), u8c(g), u8c(b), 255);
        rlClearScreenBuffers();
        rlEnableDepthTest();
    }
}

/// Present the frame.
fn end_frame() {
    unsafe { EndDrawing() }
}

/// End the 3D pass and switch to a pixel-space 2D overlay mode.
fn end_camera(width: f64, height: f64) {
    unsafe {
        EndMode3D();
        rlMatrixMode(RL_PROJECTION);
        rlLoadIdentity();
        rlOrtho(0.0, width, height, 0.0, -1.0, 1.0);
        rlMatrixMode(RL_MODELVIEW);
        rlLoadIdentity();
    }
}

/// Draw raylib's built-in FPS counter at (x, y) as a 2D overlay.
fn draw_fps(x: c_int, y: c_int) {
    unsafe { DrawFPS(x, y) }
}

/// Install a perspective camera at (px,py,pz) looking with yaw/pitch (degrees).
fn set_camera(cpx: f32, cpy: f32, cpz: f32, yaw_deg: f32, pitch_deg: f32, aspect: f32) {
    let near: f64 = 0.05;
    let far_plane: f64 = 400.0;
    let top: f64 = near * 0.57735026;
    let right: f64 = top * aspect as f64;
    unsafe {
        rlMatrixMode(RL_PROJECTION);
        rlLoadIdentity();
        rlFrustum(-right, right, -top, top, near, far_plane);
        rlMatrixMode(RL_MODELVIEW);
        rlLoadIdentity();
        rlRotatef(-pitch_deg, 1.0, 0.0, 0.0);
        rlRotatef(-yaw_deg, 0.0, 1.0, 0.0);
        rlTranslatef(-cpx, -cpy, -cpz);
    }
}

/// Emit one quad (corners 0->1->2->3, CCW) as two triangles.
#[allow(clippy::too_many_arguments)]
fn quad(
    p0: f32, p1: f32, p2: f32, p3: f32, p4: f32, p5: f32,
    p6: f32, p7: f32, p8: f32, p9: f32, p10: f32, p11: f32,
) {
    unsafe {
        rlVertex3f(p0, p1, p2);
        rlVertex3f(p3, p4, p5);
        rlVertex3f(p6, p7, p8);
        rlVertex3f(p0, p1, p2);
        rlVertex3f(p6, p7, p8);
        rlVertex3f(p9, p10, p11);
    }
}

/// Scale a 0-255 channel by a percentage (cheap face shading).
fn shade(c: i32, pct: i32) -> i32 {
    let v = c * pct / 100;
    if v < 255 { v } else { 255 }
}

/// Set the current vertex color to (r,g,b) scaled by pct.
fn shade_color(r: i32, g: i32, b: i32, pct: i32) {
    unsafe { rlColor4ub(u8c(shade(r, pct)), u8c(shade(g, pct)), u8c(shade(b, pct)), 255) }
}

/// Draw an axis-aligned colored box centered at (cx,cy,cz) with size (sx,sy,sz).
#[allow(clippy::too_many_arguments)]
fn draw_box(cx: f32, cy: f32, cz: f32, sx: f32, sy: f32, sz: f32, r: i32, g: i32, b: i32) {
    let hx = sx * 0.5;
    let hy = sy * 0.5;
    let hz = sz * 0.5;
    unsafe {
        rlPushMatrix();
        rlTranslatef(cx, cy, cz);
        rlBegin(RL_TRIANGLES);
    }

    shade_color(r, g, b, 100);
    quad(-hx, hy, hz, hx, hy, hz, hx, hy, -hz, -hx, hy, -hz);
    shade_color(r, g, b, 85);
    quad(-hx, -hy, hz, hx, -hy, hz, hx, hy, hz, -hx, hy, hz);
    quad(hx, -hy, -hz, -hx, -hy, -hz, -hx, hy, -hz, hx, hy, -hz);
    shade_color(r, g, b, 70);
    quad(hx, -hy, hz, hx, -hy, -hz, hx, hy, -hz, hx, hy, hz);
    quad(-hx, -hy, -hz, -hx, -hy, hz, -hx, hy, hz, -hx, hy, -hz);
    shade_color(r, g, b, 45);
    quad(-hx, -hy, -hz, hx, -hy, -hz, hx, -hy, hz, -hx, -hy, hz);

    unsafe {
        rlEnd();
        rlPopMatrix();
    }
}

/// Draw a flat floor grid of half*2 lines per axis, spaced step apart, on y=0.
fn draw_floor(half: i32, step: f32) {
    let ext = half as f32 * step;
    unsafe {
        rlSetLineWidth(1.0);
        rlBegin(RL_LINES);
        rlColor4ub(55, 60, 75, 255);
        for i in -half..=half {
            let f = i as f32 * step;
            rlVertex3f(f, 0.0, -ext);
            rlVertex3f(f, 0.0, ext);
            rlVertex3f(-ext, 0.0, f);
            rlVertex3f(ext, 0.0, f);
        }
        rlEnd();
    }
}

/// Benchmark duration in seconds, or 0 for normal (interactive) play. Same
/// dormant `.bench_seconds` switch as the Jac and Zig twins.
fn bench_seconds() -> f64 {
    unsafe {
        if FileExists(c".bench_seconds".as_ptr()) {
            return TextToInteger(LoadFileText(c".bench_seconds".as_ptr())) as f64;
        }
    }
    0.0
}

/// Screenshot warmup frame, or 0 for none (dormant unless `.screenshot` exists).
fn shot_frames() -> i64 {
    unsafe {
        if FileExists(c".screenshot".as_ptr()) {
            let n = TextToInteger(LoadFileText(c".screenshot".as_ptr())) as i64;
            return if n > 0 { n } else { 60 };
        }
    }
    0
}

/// Hand the benchmark result back to demo.sh via a sibling `.bench_result`
/// file (raylib's SaveFileText, not stdout), exactly as the other twins do.
fn write_bench_result(avg_fps: f64, max_fps: f64, frames: i64, seconds: f64) {
    let s = format!("BENCH_RESULT {avg_fps:.6} {max_fps:.6} {frames} {seconds:.6}");
    let s = CString::new(s).unwrap();
    unsafe {
        SaveFileText(c".bench_result".as_ptr(), s.as_ptr());
    }
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

/// Player / world state. The Jac and Zig twins keep these as module globals;
/// Rust holds them in one struct passed by `&mut` instead of `static mut`.
struct Game {
    px: f64,
    py: f64,
    pz: f64,
    yaw: f64,
    pitch: f64,
    fire_cd: f64,
    world_t: f64,
    score: i32,
    rng: i64,
    prev_mx: f64,
    prev_my: f64,
    mouse_warmup: i32,
    mouse_sens: f64,
    mouse_captured: bool,
}

#[derive(Clone, Copy)]
struct Target {
    x: f64,
    y: f64,
    z: f64,
    base_y: f64,
    phase: f64,
    alive: bool,
}

#[derive(Clone, Copy)]
struct Bullet {
    x: f64,
    y: f64,
    z: f64,
    vx: f64,
    vy: f64,
    vz: f64,
    life: f64,
}

/// One member of the flock: position, velocity, and the acceleration the
/// steering pass computes for it before the integration pass applies it.
#[derive(Clone, Copy)]
struct Boid {
    x: f64,
    y: f64,
    z: f64,
    vx: f64,
    vy: f64,
    vz: f64,
    ax: f64,
    ay: f64,
    az: f64,
}

// Flock size and steering radii (mirrors the Jac globals). Every boid looks at
// every other boid each frame: NUM_BOIDS * NUM_BOIDS neighbour tests of pure
// arithmetic - the part of the frame that runs outside raylib.
const NUM_BOIDS: usize = 256;
const BOID_VIEW2: f64 = 9.0;
const BOID_SEP2: f64 = 1.0;
const BOID_MAX_SPEED: f64 = 5.0;
const BOID_MIN_SPEED: f64 = 2.0;

/// Square root by Newton's method (12 fixed iterations, so no libm is needed).
fn jsqrt(v: f64) -> f64 {
    if v <= 0.0 {
        return 0.0;
    }
    let mut g = if v > 1.0 { v } else { 1.0 };
    let mut k = 0;
    while k < 12 {
        g = 0.5 * (g + v / g);
        k += 1;
    }
    g
}

/// Steer every boid by separation, alignment and cohesion over the neighbours
/// within its view radius (an all-pairs pass), then integrate with a speed clamp.
fn update_flock(flock: &mut [Boid], step: f64) {
    let n = flock.len();
    let mut i = 0;
    while i < n {
        let (bx, by, bz, bvx, bvy, bvz) =
            (flock[i].x, flock[i].y, flock[i].z, flock[i].vx, flock[i].vy, flock[i].vz);
        let mut cnt: i32 = 0;
        let (mut cx, mut cy, mut cz) = (0.0f64, 0.0f64, 0.0f64);
        let (mut avx, mut avy, mut avz) = (0.0f64, 0.0f64, 0.0f64);
        let (mut sx, mut sy, mut sz) = (0.0f64, 0.0f64, 0.0f64);
        let mut j = 0;
        while j < n {
            if j != i {
                let o = &flock[j];
                let dx = o.x - bx;
                let dy = o.y - by;
                let dz = o.z - bz;
                let d2 = dx * dx + dy * dy + dz * dz;
                if d2 < BOID_VIEW2 {
                    cnt += 1;
                    cx += o.x;
                    cy += o.y;
                    cz += o.z;
                    avx += o.vx;
                    avy += o.vy;
                    avz += o.vz;
                    if d2 < BOID_SEP2 {
                        let inv = 1.0 / (d2 + 0.01);
                        sx -= dx * inv;
                        sy -= dy * inv;
                        sz -= dz * inv;
                    }
                }
            }
            j += 1;
        }
        let (mut ax, mut ay, mut az) = (0.0f64, 0.0f64, 0.0f64);
        if cnt > 0 {
            let fc = cnt as f64;
            ax = (cx / fc - bx) * 0.6 + (avx / fc - bvx) * 0.9 + sx * 1.5;
            ay = (cy / fc - by) * 0.6 + (avy / fc - bvy) * 0.9 + sy * 1.5;
            az = (cz / fc - bz) * 0.6 + (avz / fc - bvz) * 0.9 + sz * 1.5;
        }
        let b = &mut flock[i];
        b.ax = ax - bx * 0.08;
        b.ay = ay + (4.0 - by) * 0.3;
        b.az = az - (bz + 5.0) * 0.08;
        i += 1;
    }
    for b in flock.iter_mut() {
        b.vx += b.ax * step;
        b.vy += b.ay * step;
        b.vz += b.az * step;
        let s2 = b.vx * b.vx + b.vy * b.vy + b.vz * b.vz;
        if s2 > BOID_MAX_SPEED * BOID_MAX_SPEED {
            let k = BOID_MAX_SPEED / jsqrt(s2);
            b.vx *= k;
            b.vy *= k;
            b.vz *= k;
        } else if s2 > 0.0 && s2 < BOID_MIN_SPEED * BOID_MIN_SPEED {
            let k = BOID_MIN_SPEED / jsqrt(s2);
            b.vx *= k;
            b.vy *= k;
            b.vz *= k;
        }
        b.x += b.vx * step;
        b.y += b.vy * step;
        b.z += b.vz * step;
    }
}

/// Draw each boid as a short streak trailing back along its velocity.
fn draw_flock(flock: &[Boid]) {
    unsafe {
        rlBegin(RL_LINES);
        rlColor4ub(120, 200, 255, 255);
        for b in flock.iter() {
            rlVertex3f(b.x as f32, b.y as f32, b.z as f32);
            rlVertex3f(
                (b.x - b.vx * 0.12) as f32,
                (b.y - b.vy * 0.12) as f32,
                (b.z - b.vz * 0.12) as f32,
            );
        }
        rlEnd();
    }
}

/// cos via range-reduced Taylor series (good to ~1e-4 on the reduced range).
fn jcos(a_in: f64) -> f64 {
    let twopi = 6.283185307179586;
    let pi = 3.141592653589793;
    let mut a = a_in;
    while a > pi {
        a -= twopi;
    }
    while a < -pi {
        a += twopi;
    }
    let x2 = a * a;
    let x4 = x2 * x2;
    let x6 = x4 * x2;
    let x8 = x4 * x4;
    let x10 = x8 * x2;
    let x12 = x8 * x4;
    1.0 - x2 / 2.0 + x4 / 24.0 - x6 / 720.0 + x8 / 40320.0 - x10 / 3628800.0 + x12 / 479001600.0
}

/// sin(a) = cos(a - pi/2).
fn jsin(a: f64) -> f64 {
    jcos(a - 1.5707963267948796)
}

impl Game {
    /// Uniform pseudo-random float in [0, 1) via a 31-bit LCG.
    fn rand01(&mut self) -> f64 {
        self.rng = (self.rng * 1103515245 + 12345) % 2147483648;
        self.rng as f64 / 2147483648.0
    }

    /// Random float in [lo, hi).
    fn rand_range(&mut self, lo: f64, hi: f64) -> f64 {
        lo + self.rand01() * (hi - lo)
    }

    /// A boid at a random spot over the arena with a random heading.
    fn spawn_boid(&mut self) -> Boid {
        let x = self.rand_range(-12.0, 12.0);
        let y = self.rand_range(1.0, 7.0);
        let z = self.rand_range(-14.0, 4.0);
        let vx = self.rand_range(-2.0, 2.0);
        let vy = self.rand_range(-0.5, 0.5);
        let vz = self.rand_range(-2.0, 2.0);
        Boid { x, y, z, vx, vy, vz, ax: 0.0, ay: 0.0, az: 0.0 }
    }

    /// (Re)place a target somewhere in the arena in front of the player.
    fn respawn(&mut self, t: &mut Target) {
        t.x = self.rand_range(-14.0, 14.0);
        t.base_y = self.rand_range(1.0, 5.0);
        t.z = self.rand_range(-16.0, 2.0);
        t.phase = self.rand_range(0.0, 6.28);
        t.y = t.base_y;
        t.alive = true;
    }

    /// Fire a bullet from the eye along the current aim, reusing a dead pool slot.
    fn fire(&self, bullets: &mut [Bullet]) {
        let yaw_r = self.yaw * DEG2RAD;
        let pitch_r = self.pitch * DEG2RAD;
        let cp = jcos(pitch_r);
        let dx = -jsin(yaw_r) * cp;
        let dy = jsin(pitch_r);
        let dz = -jcos(yaw_r) * cp;
        let speed = 40.0;
        for b in bullets.iter_mut() {
            if b.life <= 0.0 {
                b.x = self.px;
                b.y = self.py;
                b.z = self.pz;
                b.vx = dx * speed;
                b.vy = dy * speed;
                b.vz = dz * speed;
                b.life = 2.0;
                return;
            }
        }
    }

    /// Advance bullets, resolve hits against targets, and tally score.
    fn update_bullets(&mut self, bullets: &mut [Bullet], targets: &mut [Target], step: f64) {
        for b in bullets.iter_mut() {
            if b.life > 0.0 {
                b.x += b.vx * step;
                b.y += b.vy * step;
                b.z += b.vz * step;
                b.life -= step;
                for t in targets.iter_mut() {
                    if t.alive {
                        let ddx = b.x - t.x;
                        let ddy = b.y - t.y;
                        let ddz = b.z - t.z;
                        if ddx * ddx + ddy * ddy + ddz * ddz < 1.4 {
                            t.alive = false;
                            b.life = 0.0;
                            self.score += 1;
                            self.respawn(t);
                        }
                    }
                }
            }
        }
    }

    /// Read keyboard + mouse and update camera orientation + position this frame.
    fn handle_input(&mut self, step: f64) {
        let turn = 90.0 * step;

        if key_tapped(KEY_TAB) {
            if self.mouse_captured {
                unlock_mouse();
                self.mouse_captured = false;
            } else {
                lock_mouse();
                self.mouse_captured = true;
                self.mouse_warmup = 8;
            }
        }
        if !self.mouse_captured && mouse_pressed(MOUSE_LEFT) {
            lock_mouse();
            self.mouse_captured = true;
            self.mouse_warmup = 8;
        }

        if key_held(KEY_LEFT) {
            self.yaw += turn;
        }
        if key_held(KEY_RIGHT) {
            self.yaw -= turn;
        }
        if key_held(KEY_UP) {
            self.pitch += turn;
        }
        if key_held(KEY_DOWN) {
            self.pitch -= turn;
        }

        if self.mouse_captured {
            let mx = mouse_x();
            let my = mouse_y();
            if self.mouse_warmup > 0 {
                self.mouse_warmup -= 1;
            } else {
                let ddx = mx - self.prev_mx;
                let ddy = my - self.prev_my;
                if ddx < 150.0 && ddx > -150.0 && ddy < 150.0 && ddy > -150.0 {
                    self.yaw -= ddx * self.mouse_sens;
                    self.pitch -= ddy * self.mouse_sens;
                }
            }
            self.prev_mx = mx;
            self.prev_my = my;
        }

        if self.pitch > 85.0 {
            self.pitch = 85.0;
        }
        if self.pitch < -85.0 {
            self.pitch = -85.0;
        }

        let yaw_r = self.yaw * DEG2RAD;
        let fwd_x = -jsin(yaw_r);
        let fwd_z = -jcos(yaw_r);
        let rgt_x = jcos(yaw_r);
        let rgt_z = -jsin(yaw_r);
        let mv = 8.0 * step;
        if key_held(KEY_W) {
            self.px += fwd_x * mv;
            self.pz += fwd_z * mv;
        }
        if key_held(KEY_S) {
            self.px -= fwd_x * mv;
            self.pz -= fwd_z * mv;
        }
        if key_held(KEY_D) {
            self.px += rgt_x * mv;
            self.pz += rgt_z * mv;
        }
        if key_held(KEY_A) {
            self.px -= rgt_x * mv;
            self.pz -= rgt_z * mv;
        }
    }
}

const NUM_TARGETS: usize = 7;
const NUM_BULLETS: usize = 24;

fn main() {
    let mut g = Game {
        px: 0.0,
        py: 2.0,
        pz: 12.0,
        yaw: 0.0,
        pitch: 0.0,
        fire_cd: 0.0,
        world_t: 0.0,
        score: 0,
        rng: 987654321,
        prev_mx: 0.0,
        prev_my: 0.0,
        mouse_warmup: 12,
        mouse_sens: 0.12,
        mouse_captured: false,
    };

    let mut targets = [Target { x: 0.0, y: 0.0, z: 0.0, base_y: 0.0, phase: 0.0, alive: false }; NUM_TARGETS];
    let mut bullets = [Bullet { x: 0.0, y: 0.0, z: 0.0, vx: 0.0, vy: 0.0, vz: 0.0, life: 0.0 }; NUM_BULLETS];

    open_window(960, 600, c"Jac Cube Shooter (Rust)");

    for t in targets.iter_mut() {
        g.respawn(t);
    }

    // High-compute mode (dormant unless `.flock` exists): spawn the flock that
    // update_flock steers every frame. Without the file the shooter is exactly
    // the original one, as in the Jac twin.
    let flock_on = unsafe { FileExists(c".flock".as_ptr()) };
    let mut flock = [Boid { x: 0.0, y: 0.0, z: 0.0, vx: 0.0, vy: 0.0, vz: 0.0, ax: 0.0, ay: 0.0, az: 0.0 }; NUM_BOIDS];
    if flock_on {
        for b in flock.iter_mut() {
            *b = g.spawn_boid();
        }
    }

    let bench = bench_seconds();
    let shot = shot_frames();
    let mut frames: i64 = 0;
    let mut max_fps: f64 = 0.0;

    while !should_close() {
        let step = dt();
        g.world_t += step;

        frames += 1;
        if step > 0.0 {
            let inst = 1.0 / step;
            if inst > max_fps {
                max_fps = inst;
            }
        }

        g.handle_input(step);
        g.fire_cd -= step;
        if key_held(KEY_SPACE) && g.fire_cd <= 0.0 {
            g.fire(&mut bullets);
            g.fire_cd = 0.14;
        }
        g.update_bullets(&mut bullets, &mut targets, step);

        for t in targets.iter_mut() {
            t.y = t.base_y + 0.4 * jsin(g.world_t * 1.5 + t.phase);
        }
        if flock_on {
            update_flock(&mut flock, step);
        }

        begin_frame(15, 18, 28);
        set_camera(g.px as f32, g.py as f32, g.pz as f32, g.yaw as f32, g.pitch as f32, 1.6);
        draw_floor(20, 1.5);

        for t in targets.iter() {
            if t.alive {
                draw_box(t.x as f32, t.y as f32, t.z as f32, 1.4, 1.4, 1.4, 235, 80, 60);
            }
        }

        for b in bullets.iter() {
            if b.life > 0.0 {
                draw_box(b.x as f32, b.y as f32, b.z as f32, 0.22, 0.22, 0.22, 250, 220, 90);
            }
        }
        if flock_on {
            draw_flock(&flock);
        }

        end_camera(960.0, 600.0);
        draw_fps(10, 10);
        end_frame();

        // Self-screenshot path (dormant unless `.screenshot` exists).
        if shot > 0 && frames >= shot {
            unsafe { TakeScreenshot(c"shooter_shot.png".as_ptr()) };
            break;
        }

        if bench > 0.0 && unsafe { GetTime() } >= bench {
            break;
        }
    }

    if bench > 0.0 {
        let elapsed = unsafe { GetTime() };
        let avg_fps = if elapsed > 0.0 { frames as f64 / elapsed } else { 0.0 };
        write_bench_result(avg_fps, max_fps, frames, elapsed);
    }

    close_window();
}
