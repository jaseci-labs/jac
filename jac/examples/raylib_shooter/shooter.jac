"""Jac Cube Shooter - a tiny first-person 3D shooter compiled to a native binary
that links directly against a precompiled raylib shared library.

It binds raylib with Jac's native C-import syntax. The library is named by its
*logical* name - `import from raylib` - with no path and no extension; the native
backend resolves the platform-correct filename (`libraylib.so` on Linux,
`libraylib.dylib` on macOS, `raylib.dll` on Windows) from the target triple, so a
single unchanged source targets all three. Every declaration in that block becomes
an extern symbol the native linker resolves out of the shared library at load time
(a DT_NEEDED entry on ELF, an LC_LOAD_DYLIB on Mach-O); combined with the
`$ORIGIN`/`@loader_path` runpath the binary finds a sibling library regardless of
the launch directory. The linker is pure Python, so no cc/ld is needed.

The 3D pipeline deliberately uses raylib's scalar rlgl immediate-mode API
(rlVertex3f / rlColor4ub / rlTranslatef / ...) rather than the higher-level
DrawCube(Vector3) / BeginMode3D(Camera3D) by-value-struct API. The native backend
*does* lower struct-by-value calls to the platform C ABI (declare the C struct as
an obj in the import block), so the by-value entry points would work; the scalar
rlgl surface is chosen here so the shooter.zig twin stays line-for-line comparable
and the WebGL raylib_shim behind web/ - which emulates the same scalar rlgl API -
can run this one source unchanged in the browser.

Controls: mouse / arrows aim (click or Tab to capture the cursor for mouse-look),
WASD move, Space fire, Tab release / re-capture cursor, Esc quit.
"""

import from raylib {
    def InitWindow(width: i32, height: i32, title: str) -> None;  def WindowShouldClose -> bool;  def CloseWindow -> None;  def SetTargetFPS(
        fps: i32
    ) -> None;  def BeginDrawing -> None;  def EndDrawing -> None;  def rlClearColor(
        r: u8, g: u8, b: u8, a: u8
    ) -> None;  def rlClearScreenBuffers -> None;  def DrawFPS(
        pos_x: i32, pos_y: i32
    ) -> None;  def IsKeyDown(key: i32) -> bool;  def IsKeyPressed(key: i32) -> bool;  def GetFrameTime -> f32;  def GetMouseX -> i32;  def GetMouseY -> i32;  def IsMouseButtonPressed(
        button: i32
    ) -> bool;  def DisableCursor -> None;  def EnableCursor -> None;  def rlMatrixMode(
        mode: i32
    ) -> None;  def rlLoadIdentity -> None;  def rlPushMatrix -> None;  def rlPopMatrix -> None;  def rlTranslatef(
        x: f32, y: f32, z: f32
    ) -> None;  def rlRotatef(angle: f32, x: f32, y: f32, z: f32) -> None;  def rlFrustum(
        left: f64, right: f64, bottom: f64, top: f64, znear: f64, zfar: f64
    ) -> None;  def rlOrtho(
        left: f64, right: f64, bottom: f64, top: f64, znear: f64, zfar: f64
    ) -> None;  def rlBegin(mode: i32) -> None;  def rlEnd -> None;  def rlVertex3f(
        x: f32, y: f32, z: f32
    ) -> None;  def rlColor4ub(r: u8, g: u8, b: u8, a: u8) -> None;  def rlEnableDepthTest -> None;  def rlDisableDepthTest -> None;  def rlSetLineWidth(
        width: f32
    ) -> None;  def EndMode3D -> None;  def GetTime -> f64;  def FileExists(
        fileName: str
    ) -> bool;  def LoadFileText(fileName: str) -> str;  def TextToInteger(
        text: str
    ) -> i32;  def SaveFileText(fileName: str, text: str) -> bool;
}

glob RL_MODELVIEW: int = 0x1700,
     RL_PROJECTION: int = 0x1701,
     RL_LINES: int = 0x0001,
     RL_TRIANGLES: int = 0x0004;


"""Open a window. No frame-rate cap is set, so the loop runs as fast as the
hardware allows (call `SetTargetFPS` yourself if you want to limit it)."""
def open_window(width: int, height: int, title: str) {
    InitWindow(i32(width), i32(height), title);
}

"""True once the user closes the window or presses ESC."""
def should_close -> bool {
    return WindowShouldClose();
}

"""Tear the window down."""
def close_window {
    CloseWindow();
}

"""Seconds elapsed during the previous frame (for frame-rate-independent motion)."""
def dt -> float {
    return GetFrameTime();
}

"""Held-this-frame test for a raylib key code."""
def key_held(code: int) -> bool {
    return IsKeyDown(i32(code));
}

"""Pressed-this-frame (edge) test for a raylib key code."""
def key_tapped(code: int) -> bool {
    return IsKeyPressed(i32(code));
}

"""Current mouse X in pixels (as a float - see the GetMouseX note above)."""
def mouse_x -> float {
    return float(GetMouseX());
}

"""Current mouse Y in pixels (as a float)."""
def mouse_y -> float {
    return float(GetMouseY());
}

"""Pressed-this-frame test for a mouse button (0 = left)."""
def mouse_pressed(button: int) -> bool {
    return IsMouseButtonPressed(i32(button));
}

"""Hide and lock the cursor for FPS-style relative mouse-look."""
def lock_mouse {
    DisableCursor();
}

"""Show and release the cursor."""
def unlock_mouse {
    EnableCursor();
}


"""Begin a frame: clear color+depth to (r,g,b) and turn on depth testing."""
def begin_frame(r: int, g: int, b: int) {
    BeginDrawing();
    rlClearColor(u8(r), u8(g), u8(b), 255);
    rlClearScreenBuffers();
    rlEnableDepthTest();
}

"""Present the frame."""
def end_frame {
    EndDrawing();
}

"""End the 3D pass and switch to a pixel-space 2D overlay mode.

EndMode3D flushes the batch (drawing the accumulated 3D with the 3D matrices)
and disables depth testing; we then install an explicit screen-pixel ortho
projection (origin top-left) so 2D overlays land where you expect. Pairs with
set_camera, which pushes the projection matrix. `width`/`height` are the window
size in pixels. Call this before drawing any 2D overlay (e.g. the FPS counter)."""
def end_camera(width: float, height: float) {
    EndMode3D();
    rlMatrixMode(i32(RL_PROJECTION));
    rlLoadIdentity();
    rlOrtho(0.0, width, height, 0.0, -1.0, 1.0);
    rlMatrixMode(i32(RL_MODELVIEW));
    rlLoadIdentity();
}

"""Draw raylib's built-in FPS counter at (x, y) as a 2D overlay."""
def draw_fps(x: int, y: int) {
    DrawFPS(i32(x), i32(y));
}

"""Install a perspective camera at (px,py,pz) looking with yaw/pitch (degrees).

`aspect` is width/height. The projection is a 60-degree vertical FOV frustum;
the view transform is the inverse of the camera placement, built from raylib's
own rlRotatef/rlTranslatef so no by-value Matrix/Camera3D struct is needed.
"""
def set_camera(
    px: float, py: float, pz: float, yaw_deg: float, pitch_deg: float, aspect: float
) {
    near = 0.05;
    far_plane = 400.0;
    top = near * 0.57735026;
    right = top * aspect;
    rlMatrixMode(i32(RL_PROJECTION));
    rlLoadIdentity();
    rlFrustum(-right, right, -top, top, near, far_plane);
    rlMatrixMode(i32(RL_MODELVIEW));
    rlLoadIdentity();
    rlRotatef(f32(-pitch_deg), 1.0, 0.0, 0.0);
    rlRotatef(f32(-yaw_deg), 0.0, 1.0, 0.0);
    rlTranslatef(f32(-px), f32(-py), f32(-pz));
}


"""Emit one quad (corners 0->1->2->3, CCW) as two triangles.

Parameters are named p0.. rather than the natural ax,ay,az,bx,.. because the
12-float grid pattern trips a type-checker param-counting bug under a clib
import.
"""
def _quad(
    p0: float,
    p1: float,
    p2: float,
    p3: float,
    p4: float,
    p5: float,
    p6: float,
    p7: float,
    p8: float,
    p9: float,
    p10: float,
    p11: float
) {
    rlVertex3f(f32(p0), f32(p1), f32(p2));
    rlVertex3f(f32(p3), f32(p4), f32(p5));
    rlVertex3f(f32(p6), f32(p7), f32(p8));
    rlVertex3f(f32(p0), f32(p1), f32(p2));
    rlVertex3f(f32(p6), f32(p7), f32(p8));
    rlVertex3f(f32(p9), f32(p10), f32(p11));
}

"""Scale a 0-255 channel by a percentage (cheap face shading)."""
def _shade(c: int, pct: int) -> int {
    v = c * pct // 100;
    return v if v < 255 else 255;
}

"""Draw an axis-aligned colored box centered at (cx,cy,cz) with size (sx,sy,sz).

Faces are shaded by a fixed per-face brightness so the cube reads as solid
even without real lighting. Winding is CCW-outward to satisfy raylib's default
back-face culling.
"""
def draw_box(
    cx: float,
    cy: float,
    cz: float,
    sx: float,
    sy: float,
    sz: float,
    r: int,
    g: int,
    b: int
) {
    hx = sx * 0.5;
    hy = sy * 0.5;
    hz = sz * 0.5;
    rlPushMatrix();
    rlTranslatef(f32(cx), f32(cy), f32(cz));
    rlBegin(i32(RL_TRIANGLES));

    rlColor4ub(u8(_shade(r, 100)), u8(_shade(g, 100)), u8(_shade(b, 100)), 255);
    _quad(-hx, hy, hz, hx, hy, hz, hx, hy, -hz, -hx, hy, -hz);
    rlColor4ub(u8(_shade(r, 85)), u8(_shade(g, 85)), u8(_shade(b, 85)), 255);
    _quad(-hx, -hy, hz, hx, -hy, hz, hx, hy, hz, -hx, hy, hz);
    _quad(hx, -hy, -hz, -hx, -hy, -hz, -hx, hy, -hz, hx, hy, -hz);
    rlColor4ub(u8(_shade(r, 70)), u8(_shade(g, 70)), u8(_shade(b, 70)), 255);
    _quad(hx, -hy, hz, hx, -hy, -hz, hx, hy, -hz, hx, hy, hz);
    _quad(-hx, -hy, -hz, -hx, -hy, hz, -hx, hy, hz, -hx, hy, -hz);
    rlColor4ub(u8(_shade(r, 45)), u8(_shade(g, 45)), u8(_shade(b, 45)), 255);
    _quad(-hx, -hy, -hz, hx, -hy, -hz, hx, -hy, hz, -hx, -hy, hz);

    rlEnd();
    rlPopMatrix();
}

"""Draw a flat floor grid of `half*2` lines per axis, spaced `step` apart, on y=0."""
def draw_floor(half: int, step: float) {
    ext = float(half) * step;
    rlSetLineWidth(1.0);
    rlBegin(i32(RL_LINES));
    rlColor4ub(55, 60, 75, 255);
    i = -half;
    while i <= half {
        f = float(i) * step;
        rlVertex3f(f32(f), 0.0, f32(-ext));
        rlVertex3f(f32(f), 0.0, f32(ext));
        rlVertex3f(f32(-ext), 0.0, f32(f));
        rlVertex3f(f32(ext), 0.0, f32(f));
        i += 1;
    }
    rlEnd();
}


"""Seconds elapsed since the window opened (raylib's own clock)."""
def clock -> float {
    return GetTime();
}

"""Benchmark duration in seconds, or 0 for normal (interactive) play.

`demo.sh` writes the requested duration into a sibling `.bench_seconds` file
before launching, then deletes it; when that file is absent (every interactive
run, or a bare `./shooter`) this returns 0 and the game loop runs until the
window is closed. The whole benchmark path is dormant unless the file exists.
The value is read with raylib's own cross-platform file helpers, so no libc
binding is needed."""
def bench_seconds -> float {
    if FileExists(".bench_seconds") {
        return float(TextToInteger(LoadFileText(".bench_seconds")));
    }
    return 0.0;
}

"""Hand the benchmark result back to demo.sh.

raylib paints its FPS counter onto the framebuffer, never stdout, and this
repo's Jac lint rules disallow `print`, so the result is written to a sibling
`.bench_result` file via raylib's SaveFileText. Fields are positional:
avg_fps max_fps frames seconds."""
def write_bench_result(
    avg_fps: float, peak_fps: float, frame_count: int, seconds: float
) {
    SaveFileText(
        ".bench_result", f"BENCH_RESULT {avg_fps} {peak_fps} {frame_count} {seconds}"
    );
}

"""High-compute mode, or False for the original shooter.

`demo.sh` creates a sibling `.flock` file to turn on the boids flock (see
`update_flock`): 256 boids that steer against each other every frame, so the
frame spends real time in the program's own arithmetic rather than inside
raylib. Without the file none of the flock code runs and the shooter is exactly
the original one. Read with raylib's FileExists, like `.bench_seconds`."""
glob flock_mode: bool = FileExists(".flock");

"""Benchmark accumulators. `bench` is the requested duration (0 = interactive),
resolved once at startup; `frames`/`max_fps` are tallied across the run."""
glob bench: float = bench_seconds(),
     frames: int = 0,
     max_fps: float = 0.0;

glob KEY_W: int = 87,
     KEY_A: int = 65,
     KEY_S: int = 83,
     KEY_D: int = 68,
     KEY_SPACE: int = 32,
     KEY_RIGHT: int = 262,
     KEY_LEFT: int = 263,
     KEY_DOWN: int = 264,
     KEY_UP: int = 265,
     KEY_TAB: int = 258,
     MOUSE_LEFT: int = 0,
     DEG2RAD: float = 0.017453292519943295,
     px: float = 0.0,
     py: float = 2.0,
     pz: float = 12.0,
     yaw: float = 0.0,
     pitch: float = 0.0,
     fire_cd: float = 0.0,
     world_t: float = 0.0,
     score: int = 0,
     rng: int = 987654321,
     prev_mx: float = 0.0,
     prev_my: float = 0.0,
     mouse_warmup: int = 12,
     mouse_sens: float = 0.12,
     mouse_captured: bool = False;

obj Target {
    has x: float,
        y: float,
        z: float,
        base_y: float,
        phase: float,
        alive: bool;
}

obj Bullet {
    has x: float,
        y: float,
        z: float,
        vx: float,
        vy: float,
        vz: float,
        life: float;
}

"""One member of the flock: position, velocity, and the acceleration the
steering pass computes for it before the integration pass applies it."""
obj Boid {
    has x: float,
        y: float,
        z: float,
        vx: float,
        vy: float,
        vz: float,
        ax: float,
        ay: float,
        az: float;
}

"""Flock size and steering radii. Every boid looks at every other boid each
frame, so the steering pass is NUM_BOIDS * NUM_BOIDS neighbour tests of pure
arithmetic - the part of the frame that runs outside raylib."""
glob NUM_BOIDS: int = 256,
     BOID_VIEW2: float = 9.0,
     BOID_SEP2: float = 1.0,
     BOID_MAX_SPEED: float = 5.0,
     BOID_MIN_SPEED: float = 2.0;


"""cos via range-reduced Taylor series (good to ~1e-4 on the reduced range)."""
def jcos(a: float) -> float {
    twopi = 6.283185307179586;
    pi = 3.141592653589793;
    while a > pi {
        a -= twopi;
    }
    while a < -pi {
        a += twopi;
    }
    x2 = a * a;
    x4 = x2 * x2;
    x6 = x4 * x2;
    x8 = x4 * x4;
    x10 = x8 * x2;
    x12 = x8 * x4;
    return 1.0 - x2 / 2.0 + x4 / 24.0 - x6 / 720.0 + x8 / 40320.0 - x10 / 3628800.0
        + x12 / 479001600.0;
}

"""sin(a) = cos(a - pi/2)."""
def jsin(a: float) -> float {
    return jcos(a - 1.5707963267948796);
}

"""Uniform pseudo-random float in [0, 1) via a 31-bit LCG."""
def rand01 -> float {
    rng = (rng * 1103515245 + 12345) % 2147483648;
    return float(rng) / 2147483648.0;
}

"""Random float in [lo, hi)."""
def rand_range(lo: float, hi: float) -> float {
    return lo + rand01() * (hi - lo);
}


"""Square root by Newton's method (12 fixed iterations, so no libm is needed)."""
def jsqrt(v: float) -> float {
    if v <= 0.0 {
        return 0.0;
    }
    g = v if v > 1.0 else 1.0;
    k = 0;
    while k < 12 {
        g = 0.5 * (g + v / g);
        k += 1;
    }
    return g;
}

"""A boid at a random spot over the arena with a random heading."""
def spawn_boid -> Boid {
    x = rand_range(-12.0, 12.0);
    y = rand_range(1.0, 7.0);
    z = rand_range(-14.0, 4.0);
    vx = rand_range(-2.0, 2.0);
    vy = rand_range(-0.5, 0.5);
    vz = rand_range(-2.0, 2.0);
    return Boid(x=x, y=y, z=z, vx=vx, vy=vy, vz=vz, ax=0.0, ay=0.0, az=0.0);
}

"""Steer every boid by separation, alignment and cohesion over the neighbours
within its view radius (an all-pairs pass), then integrate with a speed clamp.
Steering reads only positions and velocities and writes only accelerations, so
the result does not depend on the order the boids are visited in."""
def update_flock(flock: list[Boid], step: float) {
    n = len(flock);
    i = 0;
    while i < n {
        b = flock[i];
        cnt = 0;
        cx = 0.0;
        cy = 0.0;
        cz = 0.0;
        avx = 0.0;
        avy = 0.0;
        avz = 0.0;
        sx = 0.0;
        sy = 0.0;
        sz = 0.0;
        j = 0;
        while j < n {
            if j != i {
                o = flock[j];
                dx = o.x - b.x;
                dy = o.y - b.y;
                dz = o.z - b.z;
                d2 = dx * dx + dy * dy + dz * dz;
                if d2 < BOID_VIEW2 {
                    cnt += 1;
                    cx += o.x;
                    cy += o.y;
                    cz += o.z;
                    avx += o.vx;
                    avy += o.vy;
                    avz += o.vz;
                    if d2 < BOID_SEP2 {
                        inv = 1.0 / (d2 + 0.01);
                        sx -= dx * inv;
                        sy -= dy * inv;
                        sz -= dz * inv;
                    }
                }
            }
            j += 1;
        }
        ax = 0.0;
        ay = 0.0;
        az = 0.0;
        if cnt > 0 {
            fc = float(cnt);
            ax = (cx / fc - b.x) * 0.6 + (avx / fc - b.vx) * 0.9 + sx * 1.5;
            ay = (cy / fc - b.y) * 0.6 + (avy / fc - b.vy) * 0.9 + sy * 1.5;
            az = (cz / fc - b.z) * 0.6 + (avz / fc - b.vz) * 0.9 + sz * 1.5;
        }
        b.ax = ax - b.x * 0.08;
        b.ay = ay + (4.0 - b.y) * 0.3;
        b.az = az - (b.z + 5.0) * 0.08;
        i += 1;
    }
    i = 0;
    while i < n {
        b = flock[i];
        b.vx += b.ax * step;
        b.vy += b.ay * step;
        b.vz += b.az * step;
        s2 = b.vx * b.vx + b.vy * b.vy + b.vz * b.vz;
        if s2 > BOID_MAX_SPEED * BOID_MAX_SPEED {
            k = BOID_MAX_SPEED / jsqrt(s2);
            b.vx *= k;
            b.vy *= k;
            b.vz *= k;
        } elif s2 > 0.0 and s2 < BOID_MIN_SPEED * BOID_MIN_SPEED {
            k = BOID_MIN_SPEED / jsqrt(s2);
            b.vx *= k;
            b.vy *= k;
            b.vz *= k;
        }
        b.x += b.vx * step;
        b.y += b.vy * step;
        b.z += b.vz * step;
        i += 1;
    }
}

"""Draw each boid as a short streak trailing back along its velocity."""
def draw_flock(flock: list[Boid]) {
    rlBegin(i32(RL_LINES));
    rlColor4ub(120, 200, 255, 255);
    i = 0;
    while i < len(flock) {
        b = flock[i];
        rlVertex3f(f32(b.x), f32(b.y), f32(b.z));
        rlVertex3f(
            f32(b.x - b.vx * 0.12), f32(b.y - b.vy * 0.12), f32(b.z - b.vz * 0.12)
        );
        i += 1;
    }
    rlEnd();
}

"""(Re)place a target somewhere in the arena in front of the player."""
def respawn(t: Target) {
    t.x = rand_range(-14.0, 14.0);
    t.base_y = rand_range(1.0, 5.0);
    t.z = rand_range(-16.0, 2.0);
    t.phase = rand_range(0.0, 6.28);
    t.y = t.base_y;
    t.alive = True;
}

"""Fire a bullet from the eye along the current aim, reusing a dead pool slot."""
def fire(bullets: list[Bullet]) -> None {
    yaw_r = yaw * DEG2RAD;
    pitch_r = pitch * DEG2RAD;
    cp = jcos(pitch_r);
    dx = -jsin(yaw_r) * cp;
    dy = jsin(pitch_r);
    dz = -jcos(yaw_r) * cp;
    speed = 40.0;
    i = 0;
    while i < len(bullets) {
        b = bullets[i];
        if b.life <= 0.0 {
            b.x = px;
            b.y = py;
            b.z = pz;
            b.vx = dx * speed;
            b.vy = dy * speed;
            b.vz = dz * speed;
            b.life = 2.0;
            return;
        }
        i += 1;
    }
}

"""Advance bullets, resolve hits against targets, and tally score."""
def update_bullets(bullets: list[Bullet], targets: list[Target], step: float) {
    bi = 0;
    while bi < len(bullets) {
        b = bullets[bi];
        if b.life > 0.0 {
            b.x += b.vx * step;
            b.y += b.vy * step;
            b.z += b.vz * step;
            b.life -= step;
            ti = 0;
            while ti < len(targets) {
                t = targets[ti];
                if t.alive {
                    ddx = b.x - t.x;
                    ddy = b.y - t.y;
                    ddz = b.z - t.z;
                    if ddx * ddx + ddy * ddy + ddz * ddz < 1.4 {
                        t.alive = False;
                        b.life = 0.0;
                        score += 1;
                        respawn(t);
                    }
                }
                ti += 1;
            }
        }
        bi += 1;
    }
}

"""Read keyboard + mouse and update camera orientation + position this frame."""
def handle_input(step: float) {
    turn = 90.0 * step;

    if key_tapped(KEY_TAB) {
        if mouse_captured {
            unlock_mouse();
            mouse_captured = False;
        } else {
            lock_mouse();
            mouse_captured = True;
            mouse_warmup = 8;
        }
    }
    if not mouse_captured and mouse_pressed(MOUSE_LEFT) {
        lock_mouse();
        mouse_captured = True;
        mouse_warmup = 8;
    }

    if key_held(KEY_LEFT) {
        yaw += turn;
    }
    if key_held(KEY_RIGHT) {
        yaw -= turn;
    }
    if key_held(KEY_UP) {
        pitch += turn;
    }
    if key_held(KEY_DOWN) {
        pitch -= turn;
    }

    if mouse_captured {
        mx = mouse_x();
        my = mouse_y();
        if mouse_warmup > 0 {
            mouse_warmup -= 1;
        } else {
            ddx = mx - prev_mx;
            ddy = my - prev_my;
            if ddx < 150.0 and ddx > -150.0 and ddy < 150.0 and ddy > -150.0 {
                yaw -= ddx * mouse_sens;
                pitch -= ddy * mouse_sens;
            }
        }
        prev_mx = mx;
        prev_my = my;
    }

    if pitch > 85.0 {
        pitch = 85.0;
    }
    if pitch < -85.0 {
        pitch = -85.0;
    }

    yaw_r = yaw * DEG2RAD;
    fwd_x = -jsin(yaw_r);
    fwd_z = -jcos(yaw_r);
    rgt_x = jcos(yaw_r);
    rgt_z = -jsin(yaw_r);
    move = 8.0 * step;
    if key_held(KEY_W) {
        px += fwd_x * move;
        pz += fwd_z * move;
    }
    if key_held(KEY_S) {
        px -= fwd_x * move;
        pz -= fwd_z * move;
    }
    if key_held(KEY_D) {
        px += rgt_x * move;
        pz += rgt_z * move;
    }
    if key_held(KEY_A) {
        px -= rgt_x * move;
        pz -= rgt_z * move;
    }
}


glob targets: list[Target] = [],
     bullets: list[Bullet] = [],
     flock: list[Boid] = [];

with entry {
    open_window(960, 600, "Jac Cube Shooter");

    for n in range(7) {
        t = Target(x=0.0, y=0.0, z=0.0, base_y=0.0, phase=0.0, alive=False);
        respawn(t);
        targets.append(t);
    }

    for n in range(24) {
        bullets.append(Bullet(x=0.0, y=0.0, z=0.0, vx=0.0, vy=0.0, vz=0.0, life=0.0));
    }

    if flock_mode {
        for n in range(NUM_BOIDS) {
            flock.append(spawn_boid());
        }
    }

    while not should_close() {
        step = dt();
        world_t += step;

        frames += 1;
        if step > 0.0 {
            inst = 1.0 / step;
            if inst > max_fps {
                max_fps = inst;
            }
        }

        handle_input(step);
        fire_cd -= step;
        if key_held(KEY_SPACE) and fire_cd <= 0.0 {
            fire(bullets);
            fire_cd = 0.14;
        }
        update_bullets(bullets, targets, step);

        ti = 0;
        while ti < len(targets) {
            t = targets[ti];
            t.y = t.base_y + 0.4 * jsin(world_t * 1.5 + t.phase);
            ti += 1;
        }
        if flock_mode {
            update_flock(flock, step);
        }

        begin_frame(15, 18, 28);
        set_camera(px, py, pz, yaw, pitch, 1.6);
        draw_floor(20, 1.5);

        ti = 0;
        while ti < len(targets) {
            t = targets[ti];
            if t.alive {
                draw_box(t.x, t.y, t.z, 1.4, 1.4, 1.4, 235, 80, 60);
            }
            ti += 1;
        }

        bi = 0;
        while bi < len(bullets) {
            b = bullets[bi];
            if b.life > 0.0 {
                draw_box(b.x, b.y, b.z, 0.22, 0.22, 0.22, 250, 220, 90);
            }
            bi += 1;
        }
        if flock_mode {
            draw_flock(flock);
        }

        end_camera(960.0, 600.0);
        draw_fps(10, 10);
        end_frame();

        if bench > 0.0 and clock() >= bench {
            break;
        }
    }

    if bench > 0.0 {
        elapsed = clock();
        avg_fps = 0.0;
        if elapsed > 0.0 {
            avg_fps = float(frames) / elapsed;
        }
        write_bench_result(avg_fps, max_fps, frames, elapsed);
    }

    close_window();
}
