"""Headless, fully borrow-checked twin of the cube shooter.

This is the shooter's game simulation with the renderer, window, and raylib
dependency removed - and the ownership dial turned all the way up. Every
heap-holding binding is annotated (`w: own World`, `&World` / `&mut World`
borrows, `f(&mut w)` call sites), so the whole program passes the enforced
ownership checker and compiles headerless with **no collector and zero
reference counting**, machine-checked:

    jac nacompile shooter_headless.na.jac --enforce-nogc --gc none --assert-no-rc

The same unchanged source also compiles under `--gc rc` and `--gc cycles`;
`demo.sh --headless` builds all three and checks the digests are
byte-identical, so the borrow-checked build is a semantics-preserving drop-in
(the ownbench erasure/identity discipline applied to a real game loop).

What it runs: the exact per-frame pipeline of shooter.na.jac - input, fire
cooldown, bullet integration + sphere hit tests, target respawn and bob - at a
fixed 240 Hz tick, with two substitutions so it needs no window:

- The human is replaced by a deterministic scripted pilot (yaw sweeps, pitch
  tilts, WASD-style strides, constant trigger) built from the same turn/move
  constants as `handle_input`.
- The rlgl render pass is replaced by a "virtual renderer" that walks the very
  same vertex stream `draw_floor`/`draw_box` would emit (grid lines, 6 shaded
  quads per cube, camera pose) and folds it into an integer digest instead of
  calling `rlVertex3f`. Same floats, same order - the digest is a checksum of
  every frame the real renderer would have drawn.

The target/bullet pools live as parallel arrays inside one owned `World`
(the index-arena idiom from ownbench's rbtree kernel - the design-intended
shape for pool mutation under whole-binding affine moves), rather than the
rendered twin's `list[Target]` of aliased objects.

Run `./shooter_headless [frames]`; it prints the pilot's score, the frame
digest, and an `ns=` timing line (ownbench kernel convention).
"""

import sys;
import time;

glob DEG2RAD: float = 0.017453292519943295,
     DIGEST_MOD: int = 1000000007;


"""cos via range-reduced Taylor series (identical to the rendered twin's)."""
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


"""The whole game state as one owned arena: player pose, RNG, score, and the
target/bullet pools as parallel arrays indexed by slot (SoA), so every
mutation goes through a `&mut World` borrow instead of an aliased element."""
obj World {
    has px: float = 0.0,
        py: float = 2.0,
        pz: float = 12.0,
        yaw: float = 0.0,
        pitch: float = 0.0,
        fire_cd: float = 0.0,
        world_t: float = 0.0,
        score: int = 0,
        shots: int = 0,
        rng: int = 987654321,
        tx: list[float] = [],
        ty: list[float] = [],
        tz: list[float] = [],
        tbase: list[float] = [],
        tphase: list[float] = [],
        talive: list[bool] = [],
        bpx: list[float] = [],
        bpy: list[float] = [],
        bpz: list[float] = [],
        bvx: list[float] = [],
        bvy: list[float] = [],
        bvz: list[float] = [],
        blife: list[float] = [];
}

"""Uniform pseudo-random float in [0, 1) via the same 31-bit LCG."""
def rand01(w: &mut World) -> float {
    w.rng = (w.rng * 1103515245 + 12345) % 2147483648;
    return float(w.rng) / 2147483648.0;
}

"""Random float in [lo, hi)."""
def rand_range(w: &mut World, lo: float, hi: float) -> float {
    return lo + rand01(w) * (hi - lo);
}

"""(Re)place target slot `i` somewhere in the arena in front of the player."""
def respawn(w: &mut World, i: int) {
    w.tx[i] = rand_range(w, -14.0, 14.0);
    w.tbase[i] = rand_range(w, 1.0, 5.0);
    w.tz[i] = rand_range(w, -16.0, 2.0);
    w.tphase[i] = rand_range(w, 0.0, 6.28);
    w.ty[i] = w.tbase[i];
    w.talive[i] = True;
}

"""Fire a bullet from the eye along the current aim, reusing a dead pool slot."""
def fire(w: &mut World) {
    yaw_r = w.yaw * DEG2RAD;
    pitch_r = w.pitch * DEG2RAD;
    cp = jcos(pitch_r);
    dx = -jsin(yaw_r) * cp;
    dy = jsin(pitch_r);
    dz = -jcos(yaw_r) * cp;
    speed = 40.0;
    for i in range(len(w.blife)) {
        if w.blife[i] <= 0.0 {
            w.bpx[i] = w.px;
            w.bpy[i] = w.py;
            w.bpz[i] = w.pz;
            w.bvx[i] = dx * speed;
            w.bvy[i] = dy * speed;
            w.bvz[i] = dz * speed;
            w.blife[i] = 2.0;
            w.shots += 1;
            return;
        }
    }
}

"""Advance bullets, resolve hits against targets, and tally score."""
def update_bullets(w: &mut World, step: float) {
    for bi in range(len(w.blife)) {
        if w.blife[bi] > 0.0 {
            w.bpx[bi] += w.bvx[bi] * step;
            w.bpy[bi] += w.bvy[bi] * step;
            w.bpz[bi] += w.bvz[bi] * step;
            w.blife[bi] -= step;
            for ti in range(len(w.talive)) {
                if w.talive[ti] {
                    ddx = w.bpx[bi] - w.tx[ti];
                    ddy = w.bpy[bi] - w.ty[ti];
                    ddz = w.bpz[bi] - w.tz[ti];
                    if ddx * ddx + ddy * ddy + ddz * ddz < 1.4 {
                        w.talive[ti] = False;
                        w.blife[bi] = 0.0;
                        w.score += 1;
                        respawn(w, ti);
                    }
                }
            }
        }
    }
}

"""Bob each live target on its spawn-time phase (same as the rendered loop)."""
def bob_targets(w: &mut World) {
    for ti in range(len(w.talive)) {
        w.ty[ti] = w.tbase[ti] + 0.4 * jsin(w.world_t * 1.5 + w.tphase[ti]);
    }
}

"""Deterministic scripted pilot standing in for `handle_input`.

Same turn (90 deg/s) and move (8 u/s) rates as the rendered twin; the frame
index replaces the keyboard: yaw sweeps a full circle every 4 s (wrapped at
360 so it stays bounded), pitch tilts cycle up/down/hold every 420 frames,
and the WASD stride rotates forward/right/back/left every 240. Pitch keeps
the game's +/-85 clamp and the player is boxed to the +/-20 arena so every
coordinate stays bounded (the digest depends on it).
"""
def sim_input(w: &mut World, frame: int, step: float) {
    turn = 90.0 * step;
    w.yaw += turn;
    if w.yaw >= 360.0 {
        w.yaw -= 360.0;
    }
    tilt = (frame // 420) % 3;
    if tilt == 0 {
        w.pitch += turn * 0.25;
    } elif tilt == 1 {
        w.pitch -= turn * 0.25;
    }
    if w.pitch > 85.0 {
        w.pitch = 85.0;
    }
    if w.pitch < -85.0 {
        w.pitch = -85.0;
    }

    yaw_r = w.yaw * DEG2RAD;
    fwd_x = -jsin(yaw_r);
    fwd_z = -jcos(yaw_r);
    rgt_x = jcos(yaw_r);
    rgt_z = -jsin(yaw_r);
    move = 8.0 * step;
    stride = (frame // 240) % 4;
    if stride == 0 {
        w.px += fwd_x * move;
        w.pz += fwd_z * move;
    } elif stride == 1 {
        w.px += rgt_x * move;
        w.pz += rgt_z * move;
    } elif stride == 2 {
        w.px -= fwd_x * move;
        w.pz -= fwd_z * move;
    } else {
        w.px -= rgt_x * move;
        w.pz -= rgt_z * move;
    }
    if w.px > 20.0 {
        w.px = 20.0;
    }
    if w.px < -20.0 {
        w.px = -20.0;
    }
    if w.pz > 20.0 {
        w.pz = 20.0;
    }
    if w.pz < -20.0 {
        w.pz = -20.0;
    }
}


"""Fold one vertex into the digest - the headless stand-in for `rlVertex3f`.

Coordinates are quantized at 1/8 unit; the +8000 bias keeps every term
positive (bullets reach ~ +/-102 units; native `%` is C-style on negatives)."""
def mix3(digest: int, x: float, y: float, z: float) -> int {
    ix = int(x * 8.0) + 8000;
    iy = int(y * 8.0) + 8000;
    iz = int(z * 8.0) + 8000;
    return (((digest * 31 + ix) * 31 + iy) * 31 + iz) % DIGEST_MOD;
}

"""Fold one quad (the vertex stream `_quad` emits: two CCW triangles)."""
def quad(
    digest: int,
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
) -> int {
    digest = mix3(digest, p0, p1, p2);
    digest = mix3(digest, p3, p4, p5);
    digest = mix3(digest, p6, p7, p8);
    digest = mix3(digest, p0, p1, p2);
    digest = mix3(digest, p6, p7, p8);
    digest = mix3(digest, p9, p10, p11);
    return digest;
}

"""Scale a 0-255 channel by a percentage (same shading as the renderer)."""
def shade(c: int, pct: int) -> int {
    v = c * pct // 100;
    return v if v < 255 else 255;
}

"""Fold one face color into the digest - the stand-in for `rlColor4ub`."""
def mix_color(digest: int, r: int, g: int, b: int, pct: int) -> int {
    return (
        ((digest * 31 + shade(r, pct)) * 31 + shade(g, pct)) * 31 + shade(b, pct)
    ) % DIGEST_MOD;
}

"""Fold the vertex stream `draw_box` emits: 6 shaded faces of 2 triangles,
translated to the cube's center (the renderer translates via rlTranslatef)."""
def emit_box(
    digest: int,
    cx: float,
    cy: float,
    cz: float,
    sx: float,
    sy: float,
    sz: float,
    r: int,
    g: int,
    b: int
) -> int {
    hx = sx * 0.5;
    hy = sy * 0.5;
    hz = sz * 0.5;
    x0 = cx - hx;
    x1 = cx + hx;
    y0 = cy - hy;
    y1 = cy + hy;
    z0 = cz - hz;
    z1 = cz + hz;

    digest = mix_color(digest, r, g, b, 100);
    digest = quad(digest, x0, y1, z1, x1, y1, z1, x1, y1, z0, x0, y1, z0);
    digest = mix_color(digest, r, g, b, 85);
    digest = quad(digest, x0, y0, z1, x1, y0, z1, x1, y1, z1, x0, y1, z1);
    digest = quad(digest, x1, y0, z0, x0, y0, z0, x0, y1, z0, x1, y1, z0);
    digest = mix_color(digest, r, g, b, 70);
    digest = quad(digest, x1, y0, z1, x1, y0, z0, x1, y1, z0, x1, y1, z1);
    digest = quad(digest, x0, y0, z0, x0, y0, z1, x0, y1, z1, x0, y1, z0);
    digest = mix_color(digest, r, g, b, 45);
    digest = quad(digest, x0, y0, z0, x1, y0, z0, x1, y0, z1, x0, y0, z1);
    return digest;
}

"""Fold the vertex stream `draw_floor` emits: `half*2+1` grid lines per axis."""
def emit_floor(digest: int, half: int, step: float) -> int {
    ext = float(half) * step;
    i = -half;
    while i <= half {
        f = float(i) * step;
        digest = mix3(digest, f, 0.0, -ext);
        digest = mix3(digest, f, 0.0, ext);
        digest = mix3(digest, -ext, 0.0, f);
        digest = mix3(digest, ext, 0.0, f);
        i += 1;
    }
    return digest;
}

"""Virtually render one frame through a shared borrow: camera pose, floor
grid, live targets, live bullets - the same order the rendered loop draws."""
def emit_frame(w: &World, digest: int) -> int {
    digest = mix3(digest, w.px, w.py, w.pz);
    digest = mix3(digest, w.yaw, w.pitch, 1.6);
    digest = emit_floor(digest, 20, 1.5);
    for ti in range(len(w.talive)) {
        if w.talive[ti] {
            digest = emit_box(
                digest, w.tx[ti], w.ty[ti], w.tz[ti], 1.4, 1.4, 1.4, 235, 80, 60
            );
        }
    }
    for bi in range(len(w.blife)) {
        if w.blife[bi] > 0.0 {
            digest = emit_box(
                digest, w.bpx[bi], w.bpy[bi], w.bpz[bi], 0.22, 0.22, 0.22, 250, 220, 90
            );
        }
    }
    return digest;
}


"""Simulate `frames_n` frames at a fixed 240 Hz tick and return the digest."""
def run(frames_n: int) -> int {
    w: own World = World();
    for i in range(7) {
        w.tx.append(0.0);
        w.ty.append(0.0);
        w.tz.append(0.0);
        w.tbase.append(0.0);
        w.tphase.append(0.0);
        w.talive.append(False);
        respawn(&mut w, i);
    }
    for i in range(24) {
        w.bpx.append(0.0);
        w.bpy.append(0.0);
        w.bpz.append(0.0);
        w.bvx.append(0.0);
        w.bvy.append(0.0);
        w.bvz.append(0.0);
        w.blife.append(0.0);
    }

    step = 1.0 / 240.0;
    digest = 0;
    frame = 0;
    while frame < frames_n {
        w.world_t += step;
        sim_input(&mut w, frame, step);
        w.fire_cd -= step;
        if w.fire_cd <= 0.0 {
            fire(&mut w);
            w.fire_cd = 0.14;
        }
        update_bullets(&mut w, step);
        bob_targets(&mut w);
        digest = emit_frame(&w, digest);
        frame += 1;
    }

    print("score:" + str(w.score) + " shots:" + str(w.shots));
    return (digest * 31 + w.score) % DIGEST_MOD;
}

with entry {
    frames_n = 100000;
    if len(sys.argv) > 1 {
        frames_n = int(sys.argv[1]);
    }
    t0 = time.perf_counter_ns();
    digest = run(frames_n);
    t1 = time.perf_counter_ns();
    print("shooter:" + str(digest));
    print("frames=" + str(frames_n));
    print("ns=" + str(t1 - t0));
}
