import from "@jac/wasm_host" { set_na_env }

import from .arena { init }

obj Shim {
    has gl: any = None,
        canvas: any = None,
        exports: any = None,
        game: any = None,
        mem: any = None,
        heap: any = 0,
        proj: list = [],
        mv: list = [],
        pstack: list = [],
        mvstack: list = [],
        mode: int = 0x1700,
        verts: list = [],
        color: list = [1.0, 1.0, 1.0, 1.0],
        bmode: int = 4,
        vbo: any = None,
        aPos: int = 0,
        aCol: int = 0,
        uMVP: any = None,
        keys: dict = {},
        pressed: dict = {},
        mpressed: dict = {},
        mouseX: float = 0.0,
        mouseY: float = 0.0,
        locked: bool = False,
        dt: float = 0.016,
        time: float = 0.0,
        t0: float = 0.0,
        draws: int = 0,
        on_tick: any = None,
        stopped: bool = False,
        on_key_down: any = None,
        on_key_up: any = None,
        on_mouse_down: any = None,
        on_mouse_move: any = None,
        on_lock_change: any = None;
}

# One shim for the page's lifetime: the wasm host instantiates arena.wasm
# once per module stem with the env built here, so a relaunch has to reuse
# the object those env closures captured rather than mint a new one.
glob _shim: any = None;

def _m_ident -> list {
    return [
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0
    ];
}

def _m_mul(a: list, b: list) -> list {
    c = [
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0
    ];
    col = 0;
    while col < 4 {
        row = 0;
        while row < 4 {
            s = 0.0;
            k = 0;
            while k < 4 {
                s = s + a[row + 4 * k] * b[k + 4 * col];  # jac:ignore[E1055,E1001]
                k = k + 1;
            }
            c[row + 4 * col] = s;
            row = row + 1;
        }
        col = col + 1;
    }
    return c;
}

def _m_translate(x: float, y: float, z: float) -> list {
    m = _m_ident();
    m[12] = x;
    m[13] = y;
    m[14] = z;
    return m;
}

def _m_rotate(ang: float, x: float, y: float, z: float) -> list {
    a = ang * 3.141592653589793 / 180.0;
    c = Math.cos(a);
    s = Math.sin(a);
    ln = Math.hypot(x, y, z);
    if ln == 0.0 {
        ln = 1.0;
    }
    x = x / ln;
    y = y / ln;
    z = z / ln;
    t = 1.0 - c;
    return [
        x * x * t + c,
        y * x * t + z * s,
        x * z * t - y * s,
        0.0,
        x * y * t - z * s,
        y * y * t + c,
        y * z * t + x * s,
        0.0,
        x * z * t + y * s,
        y * z * t - x * s,
        z * z * t + c,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0
    ];
}

def _m_frustum(l: float, r: float, b: float, t: float, n: float, f: float) -> list {
    return [
        2.0 * n / (r - l),
        0.0,
        0.0,
        0.0,
        0.0,
        2.0 * n / (t - b),
        0.0,
        0.0,
        (r + l) / (r - l),
        (t + b) / (t - b),
        -(f + n) / (f - n),
        -1.0,
        0.0,
        0.0,
        -2.0 * f * n / (f - n),
        0.0
    ];
}

def _m_ortho(l: float, r: float, b: float, t: float, n: float, f: float) -> list {
    return [
        2.0 / (r - l),
        0.0,
        0.0,
        0.0,
        0.0,
        2.0 / (t - b),
        0.0,
        0.0,
        0.0,
        0.0,
        -2.0 / (f - n),
        0.0,
        -(r + l) / (r - l),
        -(t + b) / (t - b),
        -(f + n) / (f - n),
        1.0
    ];
}

def _cur(sh: any) -> list {
    return sh.proj if sh.mode == 0x1701 else sh.mv;
}

def _setcur(sh: any, m: list) {
    if sh.mode == 0x1701 {
        sh.proj = m;
    } else {
        sh.mv = m;
    }
}


def _flush(sh: any) -> None {
    if len(sh.verts) == 0 {
        return;
    }
    gl = sh.gl;
    mvp = _m_mul(sh.proj, sh.mv);
    gl.bindBuffer(gl.ARRAY_BUFFER, sh.vbo);
    gl.bufferData(gl.ARRAY_BUFFER, new(Float32Array, sh.verts), gl.STREAM_DRAW);
    gl.enableVertexAttribArray(sh.aPos);
    gl.vertexAttribPointer(sh.aPos, 3, gl.FLOAT, False, 28, 0);
    gl.enableVertexAttribArray(sh.aCol);
    gl.vertexAttribPointer(sh.aCol, 4, gl.FLOAT, False, 28, 12);
    gl.uniformMatrix4fv(sh.uMVP, False, new(Float32Array, mvp));
    prim = gl.LINES if sh.bmode == 1 else gl.TRIANGLES;
    gl.drawArrays(prim, 0, len(sh.verts) // 7);
    sh.draws = sh.draws + 1;
    sh.verts = [];
}

def _build_env(sh: any) -> dict {
    return {
        "InitWindow": lambda (w: int, h: int, t: int) {},
        "WindowShouldClose": lambda { return 0; },
        "CloseWindow": lambda {},
        "SetTargetFPS": lambda (f: int) {},
        "BeginDrawing": lambda { sh.gl.viewport(0, 0, 960, 600); },
        "EndDrawing": lambda {},
        "EndMode3D": lambda { _flush(sh); },
        "GetFrameTime": lambda { return sh.dt; },
        "GetTime": lambda { return sh.time; },
        "DrawFPS": lambda (x: int, y: int) {},
        "IsKeyDown": lambda (k: int) { return sh.keys.get(k, 0); },
        "IsKeyPressed": lambda (k: int) { return sh.pressed.get(k, 0); },
        "GetMouseX": lambda { return sh.mouseX; },
        "GetMouseY": lambda { return sh.mouseY; },
        "IsMouseButtonPressed": lambda (b: int) { return sh.mpressed.get(b, 0); },
        "DisableCursor": lambda { sh.canvas.requestPointerLock(); },
        "EnableCursor": lambda { document.exitPointerLock(); },
        "rlClearColor": lambda (r: int, g: int, b: int, a: int) { sh.gl.clearColor(
            float(r) / 255.0, float(g) / 255.0, float(b) / 255.0, 1.0
        ); },
        "rlClearScreenBuffers": lambda { sh.gl.clear(16384 | 256); },
        "rlEnableDepthTest": lambda { sh.gl.enable(sh.gl.DEPTH_TEST); },
        "rlDisableDepthTest": lambda { sh.gl.disable(sh.gl.DEPTH_TEST); },
        "rlMatrixMode": lambda (m: int) { sh.mode = m; },
        "rlLoadIdentity": lambda { _setcur(sh, _m_ident()); },
        "rlPushMatrix": lambda { if sh.mode == 0x1701 {
            sh.pstack.append(sh.proj);
        } else {
            sh.mvstack.append(sh.mv);
        } },
        "rlPopMatrix": lambda { if sh.mode == 0x1701 {
            sh.proj = sh.pstack.pop();
        } else {
            sh.mv = sh.mvstack.pop();
        } },
        "rlTranslatef": lambda (x: float, y: float, z: float) { _setcur(
            sh, _m_mul(_cur(sh), _m_translate(x, y, z))
        ); },
        "rlRotatef": lambda (a: float, x: float, y: float, z: float) { _setcur(
            sh, _m_mul(_cur(sh), _m_rotate(a, x, y, z))
        ); },
        "rlFrustum": lambda (
            l: float, r: float, b: float, t: float, n: float, f: float
        ) { _setcur(sh, _m_mul(_cur(sh), _m_frustum(l, r, b, t, n, f))); },
        "rlOrtho": lambda (
            l: float, r: float, b: float, t: float, n: float, f: float
        ) { _setcur(sh, _m_mul(_cur(sh), _m_ortho(l, r, b, t, n, f))); },
        "rlBegin": lambda (m: int) {
            sh.bmode = m;
            sh.verts = [];
        },
        "rlEnd": lambda { _flush(sh); },
        "rlVertex3f": lambda (x: float, y: float, z: float) {
            sh.verts.append(x);
            sh.verts.append(y);
            sh.verts.append(z);
            sh.verts.append(sh.color[0]);
            sh.verts.append(sh.color[1]);
            sh.verts.append(sh.color[2]);
            sh.verts.append(sh.color[3]);
        },
        "rlColor4ub": lambda (r: int, g: int, b: int, a: int) { sh.color = [
            float(r) / 255.0,
            float(g) / 255.0,
            float(b) / 255.0,
            1.0
        ]; },
        "rlSetLineWidth": lambda (w: float) { sh.gl.lineWidth(w); }
    };
}

def _init_gl(sh: any) {
    gl = sh.gl;
    vs = "attribute vec3 aPos; attribute vec4 aCol; uniform mat4 uMVP; varying vec4 vCol; void main(){ gl_Position = uMVP * vec4(aPos,1.0); vCol = aCol; }";
    fs = "precision mediump float; varying vec4 vCol; void main(){ gl_FragColor = vCol; }";
    vsh = gl.createShader(gl.VERTEX_SHADER);
    gl.shaderSource(vsh, vs);
    gl.compileShader(vsh);
    fsh = gl.createShader(gl.FRAGMENT_SHADER);
    gl.shaderSource(fsh, fs);
    gl.compileShader(fsh);
    prog = gl.createProgram();
    gl.attachShader(prog, vsh);
    gl.attachShader(prog, fsh);
    gl.linkProgram(prog);
    gl.useProgram(prog);
    sh.aPos = gl.getAttribLocation(prog, "aPos");
    sh.aCol = gl.getAttribLocation(prog, "aCol");
    sh.uMVP = gl.getUniformLocation(prog, "uMVP");
    sh.vbo = gl.createBuffer();
    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.disable(gl.CULL_FACE);
}

def _keymap(code: str) -> int {
    m = {
        "KeyW": 87,
        "KeyA": 65,
        "KeyS": 83,
        "KeyD": 68,
        "Space": 32,
        "Tab": 258,
        "ArrowRight": 262,
        "ArrowLeft": 263,
        "ArrowDown": 264,
        "ArrowUp": 265
    };
    return m.get(code, 0);
}

# The game owns the keyboard only while it is engaged: the pointer is locked
# to its canvas, or the canvas is the focused element. Anywhere else on the
# page (a login form, the docs search) WASD, Space, Tab and the arrows keep
# their normal meaning.
def _engaged(sh: any) -> bool {
    return sh.locked or document.activeElement == sh.canvas;
}

def _install_input(sh: any) {
    sh.on_key_down = lambda (e: any) {
        if not _engaged(sh) {
            return;
        }
        kc = _keymap(e.code);
        if kc != 0 {
            e.preventDefault();
            sh.keys[kc] = 1;
            sh.pressed[kc] = 1;
        }
    };
    sh.on_key_up = lambda (e: any) {
        kc = _keymap(e.code);
        if kc != 0 {
            sh.keys[kc] = 0;
        }
    };
    sh.on_mouse_down = lambda (e: any) { sh.mpressed[0] = 1; };
    sh.on_mouse_move = lambda (e: any) { if sh.locked {
        sh.mouseX = sh.mouseX + e.movementX;  # jac:ignore[E1055,E1001]
        sh.mouseY = sh.mouseY + e.movementY;  # jac:ignore[E1055,E1001]
    } else {
        sh.mouseX = e.offsetX;
        sh.mouseY = e.offsetY;
    } };
    sh.on_lock_change = lambda (e: any) {
        was = sh.locked;
        sh.locked = document.pointerLockElement == sh.canvas;
        if was and not sh.locked {
            sh.pressed[258] = 1;
        }
    };
    window.addEventListener("keydown", sh.on_key_down);
    window.addEventListener("keyup", sh.on_key_up);
    sh.canvas.addEventListener("mousedown", sh.on_mouse_down);
    document.addEventListener("mousemove", sh.on_mouse_move);
    document.addEventListener("pointerlockchange", sh.on_lock_change);
}

def _remove_input(sh: any) {
    window.removeEventListener("keydown", sh.on_key_down);
    window.removeEventListener("keyup", sh.on_key_up);
    sh.canvas.removeEventListener("mousedown", sh.on_mouse_down);
    document.removeEventListener("mousemove", sh.on_mouse_move);
    document.removeEventListener("pointerlockchange", sh.on_lock_change);
}

# Halts the frame loop, drops every page-level listener and releases the
# pointer, so an unmounted game leaves nothing behind.
def _stop(sh: any) {
    if sh.stopped {
        return;
    }
    sh.stopped = True;
    _remove_input(sh);
    if sh.locked {
        document.exitPointerLock();
    }
    sh.keys = {};
    sh.pressed = {};
    sh.mpressed = {};
}

def _frame_tick(sh: any, ts: float) {
    if sh.stopped {
        return;
    }
    if sh.t0 == 0.0 {
        sh.t0 = ts;
    }
    now = (ts - sh.t0) / 1000.0;
    sh.dt = (now - sh.time) if sh.time > 0.0 else 0.016;
    if sh.dt > 0.05 {
        sh.dt = 0.05;
    }
    sh.time = now;
    closed = sh.exports.frame(sh.game);

    if sh.on_tick is not None {
        fps = Math.round(1.0 / sh.dt) if sh.dt > 0.0 else 0;
        sh.on_tick(sh.exports, sh.game, fps);
    }
    sh.pressed = {};
    sh.mpressed = {};
    if not closed {
        requestAnimationFrame(lambda (t2: float) { _frame_tick(sh, t2); });
    }
}

async def _boot(sh: any) {
    try {
        sh.game = await init();
    } except Exception as err {
        console.error("arena.wasm failed to start", err);
        return;
    }
    if sh.stopped {
        return;
    }
    requestAnimationFrame(lambda (ts: float) { _frame_tick(sh, ts); });
}

# Starts the game on `canvas` and returns a stop function. Call it when the
# canvas leaves the page: it ends the frame loop and removes the keyboard and
# mouse listeners, which otherwise outlive the landing page and swallow
# WASD / Space / Tab on every other route.
def:pub run_game(canvas: any, on_tick: any = None) -> any {
    if _shim is None {
        _shim = Shim();
        set_na_env("arena", _shim, {"env": _build_env(_shim)});
    }
    sh: any = _shim;
    sh.stopped = False;
    sh.on_tick = on_tick;
    sh.canvas = canvas;
    sh.gl = canvas.getContext("webgl");
    sh.proj = _m_ident();
    sh.mv = _m_ident();
    sh.pstack = [];
    sh.mvstack = [];
    sh.verts = [];
    sh.locked = False;
    sh.t0 = 0.0;
    sh.time = 0.0;
    _init_gl(sh);
    _install_input(sh);
    canvas.focus();

    _ = _boot(sh);
    return lambda { _stop(sh); };
}
