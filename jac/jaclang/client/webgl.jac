obj:pub WebGLHost {
    has canvas: HTMLCanvasElement,
        gl: any = None,
        exports: any = None,
        mem: any = None,
        heap: int = 0,
        proj: list[float] = [],
        mv: list[float] = [],
        pstack: list[list[float]] = [],
        mvstack: list[list[float]] = [],
        mode: int = 0x1700,
        verts: list[float] = [],
        color: list[float] = [1.0, 1.0, 1.0, 1.0],
        bmode: int = 4,
        vbo: any = None,
        aPos: int = 0,
        aCol: int = 0,
        uMVP: any = None,
        keys: dict[int, int] = {},
        pressed: dict[int, int] = {},
        mpressed: dict[int, int] = {},
        mouseX: float = 0.0,
        mouseY: float = 0.0,
        locked: bool = False,
        dt: float = 0.016,
        time: float = 0.0,
        t0: float = 0.0,
        draws: int = 0,
        program: any = None,
        on_key_down: Callable[[KeyboardEvent], None] | None = None,
        on_key_up: Callable[[KeyboardEvent], None] | None = None,
        on_mouse_down: Callable[[MouseEvent], None] | None = None,
        on_mouse_move: Callable[[MouseEvent], None] | None = None,
        on_lock_change: Callable[[Event], None] | None = None,
        on_blur: Callable[[Event], None] | None = None;

    def InitWindow(w: int, h: int, title: str) {}
    def WindowShouldClose -> bool {
        return bool(0);
    }

    def CloseWindow {}
    def SetTargetFPS(f: int) {}
    def BeginDrawing {
        self.gl.viewport(0, 0, 960, 600);
    }

    def EndDrawing {}
    def EndMode3D {
        _flush(self);
    }

    def GetFrameTime -> float {
        return self.dt;
    }

    def GetTime -> float {
        return self.time;
    }

    def DrawFPS(x: int, y: int) {}
    def IsKeyDown(k: int) -> bool {
        return bool(self.keys.get(k, 0));
    }

    def IsKeyPressed(k: int) -> bool {
        return bool(self.pressed.get(k, 0));
    }

    def GetMouseX -> int {
        return int(self.mouseX);
    }

    def GetMouseY -> int {
        return int(self.mouseY);
    }

    def IsMouseButtonPressed(b: int) -> bool {
        return bool(self.mpressed.get(b, 0));
    }

    def DisableCursor {
        self.canvas.requestPointerLock();
    }

    def EnableCursor {
        document.exitPointerLock();
    }

    def rlClearColor(r: int, g: int, b: int, a: int) {
        self.gl.clearColor(float(r) / 255.0, float(g) / 255.0, float(b) / 255.0, 1.0);
    }

    def rlClearScreenBuffers {
        self.gl.clear(16384 | 256);
    }

    def rlEnableDepthTest {
        self.gl.enable(self.gl.DEPTH_TEST);
    }

    def rlDisableDepthTest {
        self.gl.disable(self.gl.DEPTH_TEST);
    }

    def rlMatrixMode(m: int) {
        self.mode = m;
    }

    def rlLoadIdentity {
        _setcur(self, _m_ident());
    }

    def rlPushMatrix {
        if self.mode == 0x1701 {
            self.pstack.append(self.proj);
        } else {
            self.mvstack.append(self.mv);
        }
    }

    def rlPopMatrix {
        if self.mode == 0x1701 {
            self.proj = self.pstack.pop();
        } else {
            self.mv = self.mvstack.pop();
        }
    }

    def rlTranslatef(x: float, y: float, z: float) {
        _setcur(self, _m_mul(_cur(self), _m_translate(x, y, z)));
    }

    def rlRotatef(a: float, x: float, y: float, z: float) {
        _setcur(self, _m_mul(_cur(self), _m_rotate(a, x, y, z)));
    }

    def rlFrustum(l: float, r: float, b: float, t: float, n: float, f: float) {
        _setcur(self, _m_mul(_cur(self), _m_frustum(l, r, b, t, n, f)));
    }

    def rlOrtho(l: float, r: float, b: float, t: float, n: float, f: float) {
        _setcur(self, _m_mul(_cur(self), _m_ortho(l, r, b, t, n, f)));
    }

    def rlBegin(m: int) {
        self.bmode = m;
        self.verts = [];
    }

    def rlEnd {
        _flush(self);
    }

    def rlVertex3f(x: float, y: float, z: float) {
        self.verts.append(x);
        self.verts.append(y);
        self.verts.append(z);
        self.verts.append(self.color[0]);
        self.verts.append(self.color[1]);
        self.verts.append(self.color[2]);
        self.verts.append(self.color[3]);
    }

    def rlColor4ub(r: int, g: int, b: int, a: int) {
        self.color = [float(r) / 255.0, float(g) / 255.0, float(b) / 255.0, 1.0];
    }

    def rlSetLineWidth(w: float) {
        self.gl.lineWidth(w);
    }
}

def:pub _m_ident -> list[float] {
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

def _m_mul(a: list[float], b: list[float]) -> list[float] {
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
                s = s + a[row + 4 * k] * b[k + 4 * col];
                k = k + 1;
            }
            c[row + 4 * col] = s;
            row = row + 1;
        }
        col = col + 1;
    }
    return c;
}

def _m_translate(x: float, y: float, z: float) -> list[float] {
    m = _m_ident();
    m[12] = x;
    m[13] = y;
    m[14] = z;
    return m;
}

def _m_rotate(ang: float, x: float, y: float, z: float) -> list[float] {
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

def _m_frustum(
    l: float, r: float, b: float, t: float, n: float, f: float
) -> list[float] {
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

def _m_ortho(
    l: float, r: float, b: float, t: float, n: float, f: float
) -> list[float] {
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

def _cur(sh: WebGLHost) -> list[float] {
    return sh.proj if sh.mode == 0x1701 else sh.mv;
}

def _setcur(sh: WebGLHost, m: list[float]) {
    if sh.mode == 0x1701 {
        sh.proj = m;
    } else {
        sh.mv = m;
    }
}


def _flush(sh: WebGLHost) -> None {
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


def _compile_shader(gl: any, kind: int, source: str) -> any {
    shader = gl.createShader(kind);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    if not gl.getShaderParameter(shader, gl.COMPILE_STATUS) {
        message = str(gl.getShaderInfoLog(shader));
        gl.deleteShader(shader);
        raise Error("Arena shader compilation failed: " + message);
    }
    return shader;
}

def:pub _init_gl(sh: WebGLHost) {
    gl = sh.gl;
    vs = "attribute vec3 aPos; attribute vec4 aCol; uniform mat4 uMVP; varying vec4 vCol; void main(){ gl_Position = uMVP * vec4(aPos,1.0); vCol = aCol; }";
    fs = "precision mediump float; varying vec4 vCol; void main(){ gl_FragColor = vCol; }";
    vsh = _compile_shader(gl, gl.VERTEX_SHADER, vs);
    fsh: any = None;
    try {
        fsh = _compile_shader(gl, gl.FRAGMENT_SHADER, fs);
        prog = gl.createProgram();
        sh.program = prog;
        gl.attachShader(prog, vsh);
        gl.attachShader(prog, fsh);
        gl.linkProgram(prog);
        if not gl.getProgramParameter(prog, gl.LINK_STATUS) {
            raise Error("Arena shader link failed: " + str(gl.getProgramInfoLog(prog)));
        }
    } finally {
        gl.deleteShader(vsh);
        if fsh is not None {
            gl.deleteShader(fsh);
        }
    }
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

def _engaged(sh: WebGLHost) -> bool {
    return sh.locked or document.activeElement == sh.canvas;
}

def:pub _install_input(sh: WebGLHost) {
    sh.on_key_down = lambda (e: KeyboardEvent) {
        if not _engaged(sh) {
            return;
        }
        kc = _keymap(e.code);
        if kc != 0 {
            e.preventDefault();
            if not sh.keys.get(kc, 0) {
                sh.pressed[kc] = 1;
            }
            sh.keys[kc] = 1;
        }
    };
    sh.on_key_up = lambda (e: KeyboardEvent) {
        kc = _keymap(e.code);
        if kc != 0 {
            sh.keys[kc] = 0;
        }
    };
    sh.on_mouse_down = lambda (e: MouseEvent) { if e.button == 0 {
        sh.mpressed[0] = 1;
    }};
    sh.on_mouse_move = lambda (e: MouseEvent) { if sh.locked {
        sh.mouseX = sh.mouseX + e.movementX;
        sh.mouseY = sh.mouseY + e.movementY;
    } else {
        sh.mouseX = e.offsetX;
        sh.mouseY = e.offsetY;
    } };
    sh.on_lock_change = lambda (e: Event) {
        was = sh.locked;
        sh.locked = document.pointerLockElement == sh.canvas;
        if was and not sh.locked {
            sh.keys = {};
            sh.pressed = {};
            sh.pressed[258] = 1;
        }
    };
    sh.on_blur = lambda (e: Event) {
        sh.keys = {};
        sh.pressed = {};
        sh.mpressed = {};
    };
    window.addEventListener("blur", sh.on_blur);
    window.addEventListener("keydown", sh.on_key_down);
    window.addEventListener("keyup", sh.on_key_up);
    sh.canvas.addEventListener("mousedown", sh.on_mouse_down);
    document.addEventListener("mousemove", sh.on_mouse_move);
    document.addEventListener("pointerlockchange", sh.on_lock_change);
}

def:pub _remove_input(sh: WebGLHost) {
    window.removeEventListener("blur", sh.on_blur);
    window.removeEventListener("keydown", sh.on_key_down);
    window.removeEventListener("keyup", sh.on_key_up);
    sh.canvas.removeEventListener("mousedown", sh.on_mouse_down);
    document.removeEventListener("mousemove", sh.on_mouse_move);
    document.removeEventListener("pointerlockchange", sh.on_lock_change);
}
