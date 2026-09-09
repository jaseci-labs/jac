import from "@jac/wasm_host" { bind_na_host }
import from "@jac/webgl" {
    WebGLHost,
    _m_ident,
    _init_gl,
    _install_input,
    _remove_input
}
import from .arena { init, frame, get_score, get_hp, get_deaths, shutdown }
import type from .sim { Game }

obj Shim(WebGLHost) {
    has game: Game | None = None,
        on_tick: Callable[[int, float, int, int], None] | None = None,
        stopped: bool = True,
        session: int = 0,
        raf: float = 0.0;
}

glob _shim: Shim | None = None;

# Halts the frame loop, drops every page-level listener and releases the
# pointer, so an unmounted game leaves nothing behind.
def _stop(sh: Shim, session: int) {
    if sh.stopped or session != sh.session {
        return;
    }
    sh.stopped = True;
    if sh.raf {
        cancelAnimationFrame(sh.raf);
        sh.raf = 0;
    }
    try {
        game = take(sh.game);
        if game is not None {
            _ = shutdown(game);
        }
    } finally {
        _remove_input(sh);
        if document.pointerLockElement == sh.canvas {
            document.exitPointerLock();
        }
        if sh.vbo is not None {
            sh.gl.deleteBuffer(sh.vbo);
            sh.vbo = None;
        }
        if sh.program is not None {
            sh.gl.deleteProgram(sh.program);
            sh.program = None;
        }
        sh.keys = {};
        sh.pressed = {};
        sh.mpressed = {};
        sh.on_tick = None;
    }
}

async def _frame_tick(sh: Shim, session: int, ts: float) {
    if sh.stopped or session != sh.session {
        return;
    }
    sh.raf = 0;
    try {
        if sh.t0 == 0.0 {
            sh.t0 = ts;
        }
        now = (ts - sh.t0) / 1000.0;
        sh.dt = (now - sh.time) if sh.time > 0.0 else 0.016;
        if sh.dt > 0.05 {
            sh.dt = 0.05;
        }
        sh.time = now;
        game = sh.game;
        if game is None {
            _stop(sh, session);
            return;
        }
        closed = await frame(game);
        if sh.stopped or session != sh.session {
            return;
        }
        if sh.on_tick is not None {
            fps = int(Math.round(1.0 / sh.dt)) if sh.dt > 0.0 else 0;
            score = await get_score(game);
            if sh.stopped or session != sh.session {
                return;
            }
            hp = await get_hp(game);
            if sh.stopped or session != sh.session {
                return;
            }
            deaths = await get_deaths(game);
            if sh.stopped or session != sh.session {
                return;
            }
            if sh.on_tick is not None {
                sh.on_tick(score, hp, deaths, fps);
            }
        }
        sh.pressed = {};
        sh.mpressed = {};
        if closed {
            _stop(sh, session);
        } elif not sh.stopped and session == sh.session {
            sh.raf = requestAnimationFrame(
                lambda (t: float) { _frame_tick(sh, session, t); }
            );
        }
    } except Exception as err {
        if sh.stopped or session != sh.session {
            return;
        }
        _stop(sh, session);
        console.error("arena frame failed", err);
    }
}

async def _boot(sh: Shim, session: int) {
    try {
        game = await init();
        if sh.stopped or session != sh.session {
            await shutdown(game);
            return;
        }
        sh.game = game;
        sh.raf = requestAnimationFrame(
            lambda (ts: float) { _frame_tick(sh, session, ts); }
        );
    } except Exception as err {
        _stop(sh, session);
        console.error("arena.wasm failed to start", err);
    }
}

def:pub run_game(
    canvas: HTMLCanvasElement,
    on_tick: Callable[[int, float, int, int], None] | None = None
) -> Callable[[], None] {
    if _shim is None {
        _shim = Shim(canvas=canvas);
        host: Shim = _shim;
        bind_na_host(init, host);
    }
    sh = _shim;
    _stop(sh, sh.session);
    sh.session += 1;
    session = sh.session;
    sh.stopped = False;
    sh.on_tick = on_tick;
    sh.canvas = canvas;
    sh.gl = canvas.getContext("webgl");
    try {
        if sh.gl is None {
            raise Error("WebGL is unavailable");
        }
        sh.proj = _m_ident();
        sh.mv = _m_ident();
        sh.pstack = [];
        sh.mvstack = [];
        sh.verts = [];
        sh.locked = False;
        sh.mouseX = 0.0;
        sh.mouseY = 0.0;
        sh.t0 = 0.0;
        sh.time = 0.0;
        _init_gl(sh);
        _install_input(sh);
        canvas.focus();
        _ = _boot(sh, session);
    } except Exception as err {
        _stop(sh, session);
        raise err;
    }
    return lambda { _stop(sh, session); };
}
