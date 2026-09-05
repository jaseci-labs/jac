import from raylib {
    def InitWindow(width: i32, height: i32, title: str) -> None;  def WindowShouldClose -> bool;  def BeginDrawing -> None;  def EndDrawing -> None;  def rlClearColor(
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
    ) -> None;  def EndMode3D -> None;
}

glob RL_MODELVIEW: int = 0x1700,
     RL_PROJECTION: int = 0x1701,
     RL_LINES: int = 0x0001,
     RL_TRIANGLES: int = 0x0004;

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
     MOUSE_LEFT: int = 0;

glob SCREEN_W: float = 960.0,
     SCREEN_H: float = 600.0;

def open_window {
    InitWindow(i32(960), i32(600), "Jac Rocket Arena");
}

def should_close -> bool {
    return WindowShouldClose();
}

def frame_dt -> float {
    return GetFrameTime();
}

def key_held(code: int) -> bool {
    return IsKeyDown(i32(code));
}

def key_tapped(code: int) -> bool {
    return IsKeyPressed(i32(code));
}

def mouse_x -> float {
    return float(GetMouseX());
}

def mouse_y -> float {
    return float(GetMouseY());
}

def mouse_pressed(button: int) -> bool {
    return IsMouseButtonPressed(i32(button));
}

def lock_mouse {
    DisableCursor();
}

def unlock_mouse {
    EnableCursor();
}

def begin_frame(r: int, g: int, b: int);

def end_frame {
    EndDrawing();
}

def set_camera(
    px: float, py: float, pz: float, yaw_deg: float, pitch_deg: float, aspect: float
);

def begin_overlay(width: float, height: float);

def begin_model(x: float, y: float, z: float, yaw_deg: float, pitch_deg: float);

def end_model {
    rlPopMatrix();
}

def draw_fps(x: int, y: int) {
    DrawFPS(i32(x), i32(y));
}

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
);

def _shade(c: int, pct: int) -> int;

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
);

def draw_floor(half: int, step: float);

def draw_rect2d(x: float, y: float, w: float, h: float, r: int, g: int, b: int);
