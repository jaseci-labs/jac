"""Jac Cube Shooter - the Python twin of shooter.jac.

A faithful CPython port of the Jac-native shooter, kept line for line with
shooter.zig and shooter.rs so the four can be compared side by side. Like the
others it binds raylib by declaring its entry points directly - here through
the standard library's ctypes, with no bindings package - so the symbols
resolve out of the same staged libraylib shared library. Rendering goes
through the same scalar rlgl immediate-mode API, so the on-screen result is
identical, and it speaks the same .bench_seconds / .bench_result / .flock
protocol, so demo.sh's benchmark harness times it exactly like the other three,
in both the original mode and flock mode.

Run from this directory after ./demo.sh has staged libraylib:
    python3 shooter.py

Controls: mouse / arrows aim (click or Tab to capture the cursor for
mouse-look), WASD move, Space fire, Tab release / re-capture cursor, Esc quit.
"""

import ctypes
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
_LIBNAME = {"darwin": "libraylib.dylib", "win32": "raylib.dll"}.get(
    sys.platform, "libraylib.so"
)
rl = ctypes.CDLL(os.path.join(HERE, _LIBNAME))

c_int, c_bool, c_float, c_double = (
    ctypes.c_int,
    ctypes.c_bool,
    ctypes.c_float,
    ctypes.c_double,
)
c_ubyte, c_char_p = ctypes.c_ubyte, ctypes.c_char_p


def _bind(name, restype, *argtypes):
    fn = getattr(rl, name)
    fn.restype = restype
    fn.argtypes = list(argtypes)
    return fn


# ── raylib bindings (resolved from libraylib at load time) ──────────────────
InitWindow = _bind("InitWindow", None, c_int, c_int, c_char_p)
WindowShouldClose = _bind("WindowShouldClose", c_bool)
CloseWindow = _bind("CloseWindow", None)
BeginDrawing = _bind("BeginDrawing", None)
EndDrawing = _bind("EndDrawing", None)
EndMode3D = _bind("EndMode3D", None)
DrawFPS = _bind("DrawFPS", None, c_int, c_int)
GetFrameTime = _bind("GetFrameTime", c_float)
IsKeyDown = _bind("IsKeyDown", c_bool, c_int)
IsKeyPressed = _bind("IsKeyPressed", c_bool, c_int)
GetMouseX = _bind("GetMouseX", c_int)
GetMouseY = _bind("GetMouseY", c_int)
IsMouseButtonPressed = _bind("IsMouseButtonPressed", c_bool, c_int)
DisableCursor = _bind("DisableCursor", None)
EnableCursor = _bind("EnableCursor", None)
rlClearColor = _bind("rlClearColor", None, c_ubyte, c_ubyte, c_ubyte, c_ubyte)
rlClearScreenBuffers = _bind("rlClearScreenBuffers", None)
rlEnableDepthTest = _bind("rlEnableDepthTest", None)
rlMatrixMode = _bind("rlMatrixMode", None, c_int)
rlLoadIdentity = _bind("rlLoadIdentity", None)
rlPushMatrix = _bind("rlPushMatrix", None)
rlPopMatrix = _bind("rlPopMatrix", None)
rlTranslatef = _bind("rlTranslatef", None, c_float, c_float, c_float)
rlRotatef = _bind("rlRotatef", None, c_float, c_float, c_float, c_float)
rlFrustum = _bind(
    "rlFrustum", None, c_double, c_double, c_double, c_double, c_double, c_double
)
rlOrtho = _bind(
    "rlOrtho", None, c_double, c_double, c_double, c_double, c_double, c_double
)
rlBegin = _bind("rlBegin", None, c_int)
rlEnd = _bind("rlEnd", None)
rlVertex3f = _bind("rlVertex3f", None, c_float, c_float, c_float)
rlColor4ub = _bind("rlColor4ub", None, c_ubyte, c_ubyte, c_ubyte, c_ubyte)
rlSetLineWidth = _bind("rlSetLineWidth", None, c_float)
GetTime = _bind("GetTime", c_double)
FileExists = _bind("FileExists", c_bool, c_char_p)
LoadFileText = _bind("LoadFileText", c_char_p, c_char_p)
TextToInteger = _bind("TextToInteger", c_int, c_char_p)
SaveFileText = _bind("SaveFileText", c_bool, c_char_p, c_char_p)
TakeScreenshot = _bind("TakeScreenshot", None, c_char_p)

# raylib's GL matrix-mode and primitive constants (mirrors the Jac globals).
RL_MODELVIEW = 0x1700
RL_PROJECTION = 0x1701
RL_LINES = 0x0001
RL_TRIANGLES = 0x0004


# ── thin wrappers, 1:1 with the Jac source ──────────────────────────────────


def open_window(width, height, title):
    InitWindow(width, height, title)


def should_close():
    return WindowShouldClose()


def close_window():
    CloseWindow()


def dt():
    return GetFrameTime()


def key_held(code):
    return IsKeyDown(code)


def key_tapped(code):
    return IsKeyPressed(code)


def mouse_x():
    return float(GetMouseX())


def mouse_y():
    return float(GetMouseY())


def mouse_pressed(button):
    return IsMouseButtonPressed(button)


def lock_mouse():
    DisableCursor()


def unlock_mouse():
    EnableCursor()


def begin_frame(r, g, b):
    BeginDrawing()
    rlClearColor(r, g, b, 255)
    rlClearScreenBuffers()
    rlEnableDepthTest()


def end_frame():
    EndDrawing()


def end_camera(width, height):
    EndMode3D()
    rlMatrixMode(RL_PROJECTION)
    rlLoadIdentity()
    rlOrtho(0.0, width, height, 0.0, -1.0, 1.0)
    rlMatrixMode(RL_MODELVIEW)
    rlLoadIdentity()


def draw_fps(x, y):
    DrawFPS(x, y)


def set_camera(cpx, cpy, cpz, yaw_deg, pitch_deg, aspect):
    near = 0.05
    far_plane = 400.0
    top = near * 0.57735026
    right = top * aspect
    rlMatrixMode(RL_PROJECTION)
    rlLoadIdentity()
    rlFrustum(-right, right, -top, top, near, far_plane)
    rlMatrixMode(RL_MODELVIEW)
    rlLoadIdentity()
    rlRotatef(-pitch_deg, 1.0, 0.0, 0.0)
    rlRotatef(-yaw_deg, 0.0, 1.0, 0.0)
    rlTranslatef(-cpx, -cpy, -cpz)


def _quad(p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11):
    rlVertex3f(p0, p1, p2)
    rlVertex3f(p3, p4, p5)
    rlVertex3f(p6, p7, p8)
    rlVertex3f(p0, p1, p2)
    rlVertex3f(p6, p7, p8)
    rlVertex3f(p9, p10, p11)


def _shade(c, pct):
    v = (c * pct) // 100
    return v if v < 255 else 255


def draw_box(cx, cy, cz, sx, sy, sz, r, g, b):
    hx = sx * 0.5
    hy = sy * 0.5
    hz = sz * 0.5
    rlPushMatrix()
    rlTranslatef(cx, cy, cz)
    rlBegin(RL_TRIANGLES)

    rlColor4ub(_shade(r, 100), _shade(g, 100), _shade(b, 100), 255)
    _quad(-hx, hy, hz, hx, hy, hz, hx, hy, -hz, -hx, hy, -hz)
    rlColor4ub(_shade(r, 85), _shade(g, 85), _shade(b, 85), 255)
    _quad(-hx, -hy, hz, hx, -hy, hz, hx, hy, hz, -hx, hy, hz)
    _quad(hx, -hy, -hz, -hx, -hy, -hz, -hx, hy, -hz, hx, hy, -hz)
    rlColor4ub(_shade(r, 70), _shade(g, 70), _shade(b, 70), 255)
    _quad(hx, -hy, hz, hx, -hy, -hz, hx, hy, -hz, hx, hy, hz)
    _quad(-hx, -hy, -hz, -hx, -hy, hz, -hx, hy, hz, -hx, hy, -hz)
    rlColor4ub(_shade(r, 45), _shade(g, 45), _shade(b, 45), 255)
    _quad(-hx, -hy, -hz, hx, -hy, -hz, hx, -hy, hz, -hx, -hy, hz)

    rlEnd()
    rlPopMatrix()


def draw_floor(half, step):
    ext = half * step
    rlSetLineWidth(1.0)
    rlBegin(RL_LINES)
    rlColor4ub(55, 60, 75, 255)
    i = -half
    while i <= half:
        f = i * step
        rlVertex3f(f, 0.0, -ext)
        rlVertex3f(f, 0.0, ext)
        rlVertex3f(-ext, 0.0, f)
        rlVertex3f(ext, 0.0, f)
        i += 1
    rlEnd()


def bench_seconds():
    if FileExists(b".bench_seconds"):
        return float(TextToInteger(LoadFileText(b".bench_seconds")))
    return 0.0


def shot_frames():
    if FileExists(b".screenshot"):
        n = TextToInteger(LoadFileText(b".screenshot"))
        return n if n > 0 else 60
    return 0


def write_bench_result(avg_fps, max_fps, frames, seconds):
    s = "BENCH_RESULT %.6f %.6f %d %.6f" % (avg_fps, max_fps, frames, seconds)
    SaveFileText(b".bench_result", s.encode())


# ── key codes & game state (mirrors the Jac globals) ─────────────────────────

KEY_W = 87
KEY_A = 65
KEY_S = 83
KEY_D = 68
KEY_SPACE = 32
KEY_RIGHT = 262
KEY_LEFT = 263
KEY_DOWN = 264
KEY_UP = 265
KEY_TAB = 258
MOUSE_LEFT = 0
DEG2RAD = 0.017453292519943295

px = 0.0
py = 2.0
pz = 12.0
yaw = 0.0
pitch = 0.0
fire_cd = 0.0
world_t = 0.0
score = 0
rng = 987654321
prev_mx = 0.0
prev_my = 0.0
mouse_warmup = 12
mouse_sens = 0.12
mouse_captured = False


class Target:
    __slots__ = ("x", "y", "z", "base_y", "phase", "alive")

    def __init__(self):
        self.x = 0.0
        self.y = 0.0
        self.z = 0.0
        self.base_y = 0.0
        self.phase = 0.0
        self.alive = False


class Bullet:
    __slots__ = ("x", "y", "z", "vx", "vy", "vz", "life")

    def __init__(self):
        self.x = 0.0
        self.y = 0.0
        self.z = 0.0
        self.vx = 0.0
        self.vy = 0.0
        self.vz = 0.0
        self.life = 0.0


class Boid:
    """One member of the flock: position, velocity, and the acceleration the
    steering pass computes for it before the integration pass applies it."""

    __slots__ = ("x", "y", "z", "vx", "vy", "vz", "ax", "ay", "az")

    def __init__(self, x, y, z, vx, vy, vz):
        self.x = x
        self.y = y
        self.z = z
        self.vx = vx
        self.vy = vy
        self.vz = vz
        self.ax = 0.0
        self.ay = 0.0
        self.az = 0.0


# Flock size and steering radii (mirrors the Jac globals). Every boid looks at
# every other boid each frame: NUM_BOIDS * NUM_BOIDS neighbour tests of pure
# arithmetic - the part of the frame that runs outside raylib.
NUM_BOIDS = 256
BOID_VIEW2 = 9.0
BOID_SEP2 = 1.0
BOID_MAX_SPEED = 5.0
BOID_MIN_SPEED = 2.0


def jcos(a):
    twopi = 6.283185307179586
    pi = 3.141592653589793
    while a > pi:
        a -= twopi
    while a < -pi:
        a += twopi
    x2 = a * a
    x4 = x2 * x2
    x6 = x4 * x2
    x8 = x4 * x4
    x10 = x8 * x2
    x12 = x8 * x4
    return (
        1.0
        - x2 / 2.0
        + x4 / 24.0
        - x6 / 720.0
        + x8 / 40320.0
        - x10 / 3628800.0
        + x12 / 479001600.0
    )


def jsin(a):
    return jcos(a - 1.5707963267948796)


def rand01():
    global rng
    rng = (rng * 1103515245 + 12345) % 2147483648
    return rng / 2147483648.0


def rand_range(lo, hi):
    return lo + rand01() * (hi - lo)


def jsqrt(v):
    """Square root by Newton's method (12 fixed iterations, mirroring the twins)."""
    if v <= 0.0:
        return 0.0
    g = v if v > 1.0 else 1.0
    k = 0
    while k < 12:
        g = 0.5 * (g + v / g)
        k += 1
    return g


def spawn_boid():
    x = rand_range(-12.0, 12.0)
    y = rand_range(1.0, 7.0)
    z = rand_range(-14.0, 4.0)
    vx = rand_range(-2.0, 2.0)
    vy = rand_range(-0.5, 0.5)
    vz = rand_range(-2.0, 2.0)
    return Boid(x, y, z, vx, vy, vz)


def update_flock(flock, step):
    """Separation, alignment and cohesion over every pair, then integrate."""
    n = len(flock)
    i = 0
    while i < n:
        b = flock[i]
        cnt = 0
        cx = 0.0
        cy = 0.0
        cz = 0.0
        avx = 0.0
        avy = 0.0
        avz = 0.0
        sx = 0.0
        sy = 0.0
        sz = 0.0
        j = 0
        while j < n:
            if j != i:
                o = flock[j]
                dx = o.x - b.x
                dy = o.y - b.y
                dz = o.z - b.z
                d2 = dx * dx + dy * dy + dz * dz
                if d2 < BOID_VIEW2:
                    cnt += 1
                    cx += o.x
                    cy += o.y
                    cz += o.z
                    avx += o.vx
                    avy += o.vy
                    avz += o.vz
                    if d2 < BOID_SEP2:
                        inv = 1.0 / (d2 + 0.01)
                        sx -= dx * inv
                        sy -= dy * inv
                        sz -= dz * inv
            j += 1
        ax = 0.0
        ay = 0.0
        az = 0.0
        if cnt > 0:
            fc = float(cnt)
            ax = (cx / fc - b.x) * 0.6 + (avx / fc - b.vx) * 0.9 + sx * 1.5
            ay = (cy / fc - b.y) * 0.6 + (avy / fc - b.vy) * 0.9 + sy * 1.5
            az = (cz / fc - b.z) * 0.6 + (avz / fc - b.vz) * 0.9 + sz * 1.5
        b.ax = ax - b.x * 0.08
        b.ay = ay + (4.0 - b.y) * 0.3
        b.az = az - (b.z + 5.0) * 0.08
        i += 1
    i = 0
    while i < n:
        b = flock[i]
        b.vx += b.ax * step
        b.vy += b.ay * step
        b.vz += b.az * step
        s2 = b.vx * b.vx + b.vy * b.vy + b.vz * b.vz
        if s2 > BOID_MAX_SPEED * BOID_MAX_SPEED:
            k = BOID_MAX_SPEED / jsqrt(s2)
            b.vx *= k
            b.vy *= k
            b.vz *= k
        elif s2 > 0.0 and s2 < BOID_MIN_SPEED * BOID_MIN_SPEED:
            k = BOID_MIN_SPEED / jsqrt(s2)
            b.vx *= k
            b.vy *= k
            b.vz *= k
        b.x += b.vx * step
        b.y += b.vy * step
        b.z += b.vz * step
        i += 1


def draw_flock(flock):
    rlBegin(RL_LINES)
    rlColor4ub(120, 200, 255, 255)
    for b in flock:
        rlVertex3f(b.x, b.y, b.z)
        rlVertex3f(b.x - b.vx * 0.12, b.y - b.vy * 0.12, b.z - b.vz * 0.12)
    rlEnd()


def respawn(t):
    t.x = rand_range(-14.0, 14.0)
    t.base_y = rand_range(1.0, 5.0)
    t.z = rand_range(-16.0, 2.0)
    t.phase = rand_range(0.0, 6.28)
    t.y = t.base_y
    t.alive = True


def fire(bullets):
    yaw_r = yaw * DEG2RAD
    pitch_r = pitch * DEG2RAD
    cp = jcos(pitch_r)
    dx = -jsin(yaw_r) * cp
    dy = jsin(pitch_r)
    dz = -jcos(yaw_r) * cp
    speed = 40.0
    for b in bullets:
        if b.life <= 0.0:
            b.x = px
            b.y = py
            b.z = pz
            b.vx = dx * speed
            b.vy = dy * speed
            b.vz = dz * speed
            b.life = 2.0
            return


def update_bullets(bullets, targets, step):
    global score
    for b in bullets:
        if b.life > 0.0:
            b.x += b.vx * step
            b.y += b.vy * step
            b.z += b.vz * step
            b.life -= step
            for t in targets:
                if t.alive:
                    ddx = b.x - t.x
                    ddy = b.y - t.y
                    ddz = b.z - t.z
                    if ddx * ddx + ddy * ddy + ddz * ddz < 1.4:
                        t.alive = False
                        b.life = 0.0
                        score += 1
                        respawn(t)


def handle_input(step):
    global yaw, pitch, px, pz, prev_mx, prev_my, mouse_warmup, mouse_captured
    turn = 90.0 * step

    if key_tapped(KEY_TAB):
        if mouse_captured:
            unlock_mouse()
            mouse_captured = False
        else:
            lock_mouse()
            mouse_captured = True
            mouse_warmup = 8
    if not mouse_captured and mouse_pressed(MOUSE_LEFT):
        lock_mouse()
        mouse_captured = True
        mouse_warmup = 8

    if key_held(KEY_LEFT):
        yaw += turn
    if key_held(KEY_RIGHT):
        yaw -= turn
    if key_held(KEY_UP):
        pitch += turn
    if key_held(KEY_DOWN):
        pitch -= turn

    if mouse_captured:
        mx = mouse_x()
        my = mouse_y()
        if mouse_warmup > 0:
            mouse_warmup -= 1
        else:
            ddx = mx - prev_mx
            ddy = my - prev_my
            if ddx < 150.0 and ddx > -150.0 and ddy < 150.0 and ddy > -150.0:
                yaw -= ddx * mouse_sens
                pitch -= ddy * mouse_sens
        prev_mx = mx
        prev_my = my

    if pitch > 85.0:
        pitch = 85.0
    if pitch < -85.0:
        pitch = -85.0

    yaw_r = yaw * DEG2RAD
    fwd_x = -jsin(yaw_r)
    fwd_z = -jcos(yaw_r)
    rgt_x = jcos(yaw_r)
    rgt_z = -jsin(yaw_r)
    move = 8.0 * step
    if key_held(KEY_W):
        px += fwd_x * move
        pz += fwd_z * move
    if key_held(KEY_S):
        px -= fwd_x * move
        pz -= fwd_z * move
    if key_held(KEY_D):
        px += rgt_x * move
        pz += rgt_z * move
    if key_held(KEY_A):
        px -= rgt_x * move
        pz -= rgt_z * move


NUM_TARGETS = 7
NUM_BULLETS = 24


def main():
    global world_t, fire_cd
    targets = [Target() for _ in range(NUM_TARGETS)]
    bullets = [Bullet() for _ in range(NUM_BULLETS)]

    open_window(960, 600, b"Jac Cube Shooter (Python)")

    for t in targets:
        respawn(t)

    # High-compute mode (dormant unless `.flock` exists), as in the Jac twin.
    flock_on = FileExists(b".flock")
    flock = [spawn_boid() for _ in range(NUM_BOIDS)] if flock_on else []

    bench = bench_seconds()
    shot = shot_frames()
    frames = 0
    max_fps = 0.0

    while not should_close():
        step = dt()
        world_t += step

        frames += 1
        if step > 0.0:
            inst = 1.0 / step
            if inst > max_fps:
                max_fps = inst

        handle_input(step)
        fire_cd -= step
        if key_held(KEY_SPACE) and fire_cd <= 0.0:
            fire(bullets)
            fire_cd = 0.14
        update_bullets(bullets, targets, step)

        for t in targets:
            t.y = t.base_y + 0.4 * jsin(world_t * 1.5 + t.phase)
        if flock_on:
            update_flock(flock, step)

        begin_frame(15, 18, 28)
        set_camera(px, py, pz, yaw, pitch, 1.6)
        draw_floor(20, 1.5)

        for t in targets:
            if t.alive:
                draw_box(t.x, t.y, t.z, 1.4, 1.4, 1.4, 235, 80, 60)

        for b in bullets:
            if b.life > 0.0:
                draw_box(b.x, b.y, b.z, 0.22, 0.22, 0.22, 250, 220, 90)
        if flock_on:
            draw_flock(flock)

        end_camera(960.0, 600.0)
        draw_fps(10, 10)
        end_frame()

        if shot > 0 and frames >= shot:
            TakeScreenshot(b"shooter_shot.png")
            break

        if bench > 0.0 and GetTime() >= bench:
            break

    if bench > 0.0:
        elapsed = GetTime()
        avg_fps = frames / elapsed if elapsed > 0.0 else 0.0
        write_bench_result(avg_fps, max_fps, frames, elapsed)

    close_window()


if __name__ == "__main__":
    os.chdir(HERE)
    main()
