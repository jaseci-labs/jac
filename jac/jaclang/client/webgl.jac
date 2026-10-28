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

    def InitWindow(w: int, h: int, title: str);
    def WindowShouldClose -> bool;
    def CloseWindow;
    def SetTargetFPS(f: int);
    def BeginDrawing;
    def EndDrawing;
    def EndMode3D;
    def GetFrameTime -> float;
    def GetTime -> float;
    def DrawFPS(x: int, y: int);
    def IsKeyDown(k: int) -> bool;
    def IsKeyPressed(k: int) -> bool;
    def GetMouseX -> int;
    def GetMouseY -> int;
    def IsMouseButtonPressed(b: int) -> bool;
    def DisableCursor;
    def EnableCursor;
    def rlClearColor(r: int, g: int, b: int, a: int);
    def rlClearScreenBuffers;
    def rlEnableDepthTest;
    def rlDisableDepthTest;
    def rlMatrixMode(m: int);
    def rlLoadIdentity;
    def rlPushMatrix;
    def rlPopMatrix;
    def rlTranslatef(x: float, y: float, z: float);
    def rlRotatef(a: float, x: float, y: float, z: float);
    def rlFrustum(l: float, r: float, b: float, t: float, n: float, f: float);
    def rlOrtho(l: float, r: float, b: float, t: float, n: float, f: float);
    def rlBegin(m: int);
    def rlEnd;
    def rlVertex3f(x: float, y: float, z: float);
    def rlColor4ub(r: int, g: int, b: int, a: int);
    def rlSetLineWidth(w: float);
}

def:pub _m_ident -> list[float];

def _m_mul(a: list[float], b: list[float]) -> list[float];

def _m_translate(x: float, y: float, z: float) -> list[float];

def _m_rotate(ang: float, x: float, y: float, z: float) -> list[float];

def _m_frustum(
    l: float, r: float, b: float, t: float, n: float, f: float
) -> list[float];

def _m_ortho(
    l: float, r: float, b: float, t: float, n: float, f: float
) -> list[float];

def _cur(sh: WebGLHost) -> list[float];

def _setcur(sh: WebGLHost, m: list[float]);


def _flush(sh: WebGLHost) -> None;


def _compile_shader(gl: any, kind: int, source: str) -> any;

def:pub _init_gl(sh: WebGLHost);

def _keymap(code: str) -> int;

def _engaged(sh: WebGLHost) -> bool;

def:pub _install_input(sh: WebGLHost);

def:pub _remove_input(sh: WebGLHost);
