# Single-file full-stack build: the SAME rlgl shooter as ../shooter.na.jac,
# now an na{} codespace compiled to wasm by `jac build`/`jac start`, with a
# cl{} WebGL shim + page in the same module. Run: jac start (open localhost).

# ─── Client: the page + HUD. The WebGL shim (rlgl/input/libc -> wasm imports) is
# the reusable raylib_shim.cl.jac library; here we mount the canvas, style the
# page like the standalone web build, and drive a live score/fps HUD. ──────────
cl {
    import from .raylib_shim { run_game }

    def:pub app -> JsxElement {
        can with entry {
            existing: any = document.getElementById("shooter-styles");
            if not existing {
                css = """
                body { margin: 0; background: #0b0e16; }
                #page { min-height: 100vh; box-sizing: border-box; color: #cdd6e6;
                        font: 14px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace;
                        display: flex; flex-direction: column; align-items: center;
                        gap: 12px; padding: 18px; }
                #page h1 { font-size: 16px; font-weight: 600; margin: 4px 0 0; }
                #hint { opacity: 0.7; }
                #hint b, #hud b { color: #f5c451; }
                #wrap { position: relative; }
                #glcanvas { background: #0f121c; border: 1px solid #232a3d;
                            border-radius: 6px; display: block; cursor: crosshair; }
                #hud { position: absolute; top: 8px; left: 10px; pointer-events: none;
                       text-shadow: 0 1px 2px #000; }
                """;
                st: any = document.createElement("style");
                st.id = "shooter-styles";
                st.textContent = css;
                head: any = document.head;
                head.appendChild(st);
            }
            run_game(
                document.getElementById("glcanvas"),
                lambda (exports: any, fps: int) {
                    score_el: any = document.getElementById("hud-score");
                    fps_el: any = document.getElementById("hud-fps");
                    score_el.textContent = exports.get_score();
                    fps_el.textContent = fps;
                }
            );
        }
        # The inter-element spaces below are written as explicit {" "} string
        # children on purpose: `jac format` reflows mixed JSX (text next to
        # inline elements) onto separate lines and drops the significant
        # whitespace, so plain `mouse · <b>WASD</b> move` would render as
        # `mouse ·WASDmove`. Keep these literals until the formatter preserves
        # JSX whitespace on break.
        return
            <div id="page">
                <h1>Jac Cube Shooter - na wasm + cl WebGL, one app module</h1>
                <div id="hint">
                    {"Click the canvas to capture the mouse · "}
                    <b>WASD</b>
                    {" move · mouse/arrows aim · "}
                    <b>Space</b>
                    {" fire · "}
                    <b>Tab</b>
                    {" release"}
                </div>
                <div id="wrap">
                    <canvas id="glcanvas" width={960} height={600}></canvas>
                    <div id="hud">
                        {"score "}
                        <b id="hud-score">0</b>
                        {" · "}
                        <b id="hud-fps">0</b>
                        {" fps"}
                    </div>
                </div>
            </div>;
    }
}

na {
    import from raylib {
        def InitWindow(width: i32, height: i32, title: str) -> None;  def WindowShouldClose -> bool;  def CloseWindow -> None;  def SetTargetFPS(
            fps: i32
        ) -> None;  def BeginDrawing -> None;  def EndDrawing -> None;  def rlClearColor(
            r: u8, g: u8, b: u8, a: u8
        ) -> None;  def rlClearScreenBuffers -> None;  def DrawFPS(
            pos_x: i32, pos_y: i32
        ) -> None;  def IsKeyDown(key: i32) -> bool;  def IsKeyPressed(
            key: i32
        ) -> bool;  def GetFrameTime -> f32;  def GetMouseX -> i32;  def GetMouseY -> i32;  def IsMouseButtonPressed(
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
        InitWindow(width, height, title);
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
        return IsKeyDown(code);
    }

    """Pressed-this-frame (edge) test for a raylib key code."""
    def key_tapped(code: int) -> bool {
        return IsKeyPressed(code);
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
        return IsMouseButtonPressed(button);
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
        rlClearColor(r, g, b, 255);
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
        rlMatrixMode(RL_PROJECTION);
        rlLoadIdentity();
        rlOrtho(0.0, width, height, 0.0, -1.0, 1.0);
        rlMatrixMode(RL_MODELVIEW);
        rlLoadIdentity();
    }

    """Draw raylib's built-in FPS counter at (x, y) as a 2D overlay."""
    def draw_fps(x: int, y: int) {
        DrawFPS(x, y);
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
        rlMatrixMode(RL_PROJECTION);
        rlLoadIdentity();
        rlFrustum(-right, right, -top, top, near, far_plane);
        rlMatrixMode(RL_MODELVIEW);
        rlLoadIdentity();
        rlRotatef(-pitch_deg, 1.0, 0.0, 0.0);
        rlRotatef(-yaw_deg, 0.0, 1.0, 0.0);
        rlTranslatef(-px, -py, -pz);
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
        rlVertex3f(p0, p1, p2);
        rlVertex3f(p3, p4, p5);
        rlVertex3f(p6, p7, p8);
        rlVertex3f(p0, p1, p2);
        rlVertex3f(p6, p7, p8);
        rlVertex3f(p9, p10, p11);
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
        rlTranslatef(cx, cy, cz);
        rlBegin(RL_TRIANGLES);

        rlColor4ub(_shade(r, 100), _shade(g, 100), _shade(b, 100), 255);
        _quad(-hx, hy, hz, hx, hy, hz, hx, hy, -hz, -hx, hy, -hz);
        rlColor4ub(_shade(r, 85), _shade(g, 85), _shade(b, 85), 255);
        _quad(-hx, -hy, hz, hx, -hy, hz, hx, hy, hz, -hx, hy, hz);
        _quad(hx, -hy, -hz, -hx, -hy, -hz, -hx, hy, -hz, hx, hy, -hz);
        rlColor4ub(_shade(r, 70), _shade(g, 70), _shade(b, 70), 255);
        _quad(hx, -hy, hz, hx, -hy, -hz, hx, hy, -hz, hx, hy, hz);
        _quad(-hx, -hy, -hz, -hx, -hy, hz, -hx, hy, hz, -hx, hy, -hz);
        rlColor4ub(_shade(r, 45), _shade(g, 45), _shade(b, 45), 255);
        _quad(-hx, -hy, -hz, hx, -hy, -hz, hx, -hy, hz, -hx, -hy, hz);

        rlEnd();
        rlPopMatrix();
    }

    """Draw a flat floor grid of `half*2` lines per axis, spaced `step` apart, on y=0."""
    def draw_floor(half: int, step: float) {
        ext = float(half) * step;
        rlSetLineWidth(1.0);
        rlBegin(RL_LINES);
        rlColor4ub(55, 60, 75, 255);
        i = -half;
        while i <= half {
            f = float(i) * step;
            rlVertex3f(f, 0.0, -ext);
            rlVertex3f(f, 0.0, ext);
            rlVertex3f(-ext, 0.0, f);
            rlVertex3f(ext, 0.0, f);
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
            ".bench_result",
            f"BENCH_RESULT {avg_fps} {peak_fps} {frame_count} {seconds}"
        );
    }

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
        return 1.0 - x2 / 2.0 + x4 / 24.0 - x6 / 720.0 + x8 / 40320.0 - x10 / 3628800.0 + x12 / 479001600.0;
    }

    """sin(a) = cos(a - pi/2)."""
    def jsin(a: float) -> float {
        return jcos(a - 1.5707963267948796);
    }

    """Uniform pseudo-random float in [0, 1) via a 31-bit LCG."""
    def rand01 -> float {
        global rng;
        rng = (rng * 1103515245 + 12345) % 2147483648;
        return float(rng) / 2147483648.0;
    }

    """Random float in [lo, hi)."""
    def rand_range(lo: float, hi: float) -> float {
        return lo + rand01() * (hi - lo);
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
        global score;
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
        global yaw,pitch,px,pz,prev_mx,prev_my,mouse_warmup,mouse_captured;
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
         bullets: list[Bullet] = [];

    # ─── Browser entry points (replace the native `with entry` loop) ─────────────
    """Set up the window and object pools. Call once before the first frame()."""
    def init {
        global targets,bullets;
        open_window(960, 600, "Jac Cube Shooter");
        for n in range(7) {
            t = Target(x=0.0, y=0.0, z=0.0, base_y=0.0, phase=0.0, alive=False);
            respawn(t);
            targets.append(t);
        }
        for n in range(24) {
            bullets.append(
                Bullet(x=0.0, y=0.0, z=0.0, vx=0.0, vy=0.0, vz=0.0, life=0.0)
            );
        }
    }

    """Advance and render one frame. Returns True when the game wants to close."""
    def frame -> bool {
        global world_t,fire_cd;
        step = dt();
        world_t += step;
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
        end_camera(960.0, 600.0);
        draw_fps(10, 10);
        end_frame();
        return should_close();
    }

    """Current score (targets destroyed) - for an HTML/`sv` HUD."""
    def get_score -> int {
        return score;
    }
}
