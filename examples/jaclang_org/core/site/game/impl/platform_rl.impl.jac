impl begin_frame(r: int, g: int, b: int) {
    BeginDrawing();
    rlClearColor(r, g, b, 255);
    rlClearScreenBuffers();
    rlEnableDepthTest();
}

impl set_camera(px: float, py: float, pz: float, yaw_deg: float, pitch_deg: float, aspect: float) {
    near = 0.05;
    far_plane = 400.0;
    top = near * 0.57735026;
    right = top * aspect;
    rlMatrixMode(RL_PROJECTION);
    rlLoadIdentity();
    rlFrustum(f64(-right), f64(right), f64(-top), f64(top), f64(near), f64(far_plane));
    rlMatrixMode(RL_MODELVIEW);
    rlLoadIdentity();
    rlRotatef(-pitch_deg, 1.0, 0.0, 0.0);
    rlRotatef(-yaw_deg, 0.0, 1.0, 0.0);
    rlTranslatef(-px, -py, -pz);
}

impl begin_overlay(width: float, height: float) {
    EndMode3D();
    rlMatrixMode(RL_PROJECTION);
    rlLoadIdentity();
    rlOrtho(f64(0.0), f64(width), f64(height), f64(0.0), f64(-1.0), f64(1.0));
    rlMatrixMode(RL_MODELVIEW);
    rlLoadIdentity();
    rlDisableDepthTest();
}

impl begin_model(x: float, y: float, z: float, yaw_deg: float, pitch_deg: float) {
    rlPushMatrix();
    rlTranslatef(x, y, z);
    rlRotatef(yaw_deg, 0.0, 1.0, 0.0);
    rlRotatef(pitch_deg, 1.0, 0.0, 0.0);
}

impl _quad(
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
    p11: float,
) {
    rlVertex3f(p0, p1, p2);
    rlVertex3f(p3, p4, p5);
    rlVertex3f(p6, p7, p8);
    rlVertex3f(p0, p1, p2);
    rlVertex3f(p6, p7, p8);
    rlVertex3f(p9, p10, p11);
}

impl _shade(c: int, pct: int) -> int {
    v = c * pct // 100;
    return v if v < 255 else 255;
}

impl draw_box(
    cx: float, cy: float, cz: float, sx: float, sy: float, sz: float, r: int, g: int, b: int
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

impl draw_floor(half: int, step: float) {
    ext = float(half) * step;
    rlSetLineWidth(1.0);
    rlBegin(RL_LINES);
    rlColor4ub(52, 52, 58, 255);
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

impl draw_rect2d(x: float, y: float, w: float, h: float, r: int, g: int, b: int) {
    rlBegin(RL_TRIANGLES);
    rlColor4ub(r, g, b, 255);
    rlVertex3f(x, y, 0.0);
    rlVertex3f(x, y + h, 0.0);
    rlVertex3f(x + w, y + h, 0.0);
    rlVertex3f(x, y, 0.0);
    rlVertex3f(x + w, y + h, 0.0);
    rlVertex3f(x + w, y, 0.0);
    rlEnd();
}

impl open_window {
    InitWindow(960, 600, "Jac Rocket Arena");
}

impl should_close -> bool {
    return WindowShouldClose();
}

impl frame_dt -> float {
    return float(GetFrameTime());
}

impl key_held(code: int) -> bool {
    return IsKeyDown(code);
}

impl key_tapped(code: int) -> bool {
    return IsKeyPressed(code);
}

impl mouse_x -> float {
    return float(GetMouseX());
}

impl mouse_y -> float {
    return float(GetMouseY());
}

impl mouse_pressed(button: int) -> bool {
    return IsMouseButtonPressed(button);
}

impl lock_mouse {
    DisableCursor();
}

impl unlock_mouse {
    EnableCursor();
}

impl end_frame {
    EndDrawing();
}

impl end_model {
    rlPopMatrix();
}

impl draw_fps(x: int, y: int) {
    DrawFPS(x, y);
}

impl close_window {
    CloseWindow();
}
