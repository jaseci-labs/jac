impl begin_frame(r: int, g: int, b: int) {
    BeginDrawing();
    rlClearColor(u8(r), u8(g), u8(b), u8(255));
    rlClearScreenBuffers();
    rlEnableDepthTest();
}

impl set_camera(
    px: float, py: float, pz: float, yaw_deg: float, pitch_deg: float, aspect: float
) {
    near = 0.05;
    far_plane = 400.0;
    top = near * 0.57735026;
    right = top * aspect;
    rlMatrixMode(i32(RL_PROJECTION));
    rlLoadIdentity();
    rlFrustum(f64(-right), f64(right), f64(-top), f64(top), f64(near), f64(far_plane));
    rlMatrixMode(i32(RL_MODELVIEW));
    rlLoadIdentity();
    rlRotatef(f32(-pitch_deg), f32(1.0), f32(0.0), f32(0.0));
    rlRotatef(f32(-yaw_deg), f32(0.0), f32(1.0), f32(0.0));
    rlTranslatef(f32(-px), f32(-py), f32(-pz));
}

impl begin_overlay(width: float, height: float) {
    EndMode3D();
    rlMatrixMode(i32(RL_PROJECTION));
    rlLoadIdentity();
    rlOrtho(f64(0.0), f64(width), f64(height), f64(0.0), f64(-1.0), f64(1.0));
    rlMatrixMode(i32(RL_MODELVIEW));
    rlLoadIdentity();
    rlDisableDepthTest();
}

impl begin_model(x: float, y: float, z: float, yaw_deg: float, pitch_deg: float) {
    rlPushMatrix();
    rlTranslatef(f32(x), f32(y), f32(z));
    rlRotatef(f32(yaw_deg), f32(0.0), f32(1.0), f32(0.0));
    rlRotatef(f32(pitch_deg), f32(1.0), f32(0.0), f32(0.0));
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
    p11: float
) {
    rlVertex3f(f32(p0), f32(p1), f32(p2));
    rlVertex3f(f32(p3), f32(p4), f32(p5));
    rlVertex3f(f32(p6), f32(p7), f32(p8));
    rlVertex3f(f32(p0), f32(p1), f32(p2));
    rlVertex3f(f32(p6), f32(p7), f32(p8));
    rlVertex3f(f32(p9), f32(p10), f32(p11));
}

impl _shade(c: int, pct: int) -> int {
    v = c * pct // 100;
    return v if v < 255 else 255;
}

impl draw_box(
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

    rlColor4ub(u8(_shade(r, 100)), u8(_shade(g, 100)), u8(_shade(b, 100)), u8(255));
    _quad(-hx, hy, hz, hx, hy, hz, hx, hy, -hz, -hx, hy, -hz);
    rlColor4ub(u8(_shade(r, 85)), u8(_shade(g, 85)), u8(_shade(b, 85)), u8(255));
    _quad(-hx, -hy, hz, hx, -hy, hz, hx, hy, hz, -hx, hy, hz);
    _quad(hx, -hy, -hz, -hx, -hy, -hz, -hx, hy, -hz, hx, hy, -hz);
    rlColor4ub(u8(_shade(r, 70)), u8(_shade(g, 70)), u8(_shade(b, 70)), u8(255));
    _quad(hx, -hy, hz, hx, -hy, -hz, hx, hy, -hz, hx, hy, hz);
    _quad(-hx, -hy, -hz, -hx, -hy, hz, -hx, hy, hz, -hx, hy, -hz);
    rlColor4ub(u8(_shade(r, 45)), u8(_shade(g, 45)), u8(_shade(b, 45)), u8(255));
    _quad(-hx, -hy, -hz, hx, -hy, -hz, hx, -hy, hz, -hx, -hy, hz);

    rlEnd();
    rlPopMatrix();
}

impl draw_floor(half: int, step: float) {
    ext = float(half) * step;
    rlSetLineWidth(f32(1.0));
    rlBegin(i32(RL_LINES));
    rlColor4ub(u8(52), u8(52), u8(58), u8(255));
    i = -half;
    while i <= half {
        f = float(i) * step;
        rlVertex3f(f32(f), f32(0.0), f32(-ext));
        rlVertex3f(f32(f), f32(0.0), f32(ext));
        rlVertex3f(f32(-ext), f32(0.0), f32(f));
        rlVertex3f(f32(ext), f32(0.0), f32(f));
        i += 1;
    }
    rlEnd();
}

impl draw_rect2d(x: float, y: float, w: float, h: float, r: int, g: int, b: int) {
    rlBegin(i32(RL_TRIANGLES));
    rlColor4ub(u8(r), u8(g), u8(b), u8(255));
    rlVertex3f(f32(x), f32(y), f32(0.0));
    rlVertex3f(f32(x), f32(y + h), f32(0.0));
    rlVertex3f(f32(x + w), f32(y + h), f32(0.0));
    rlVertex3f(f32(x), f32(y), f32(0.0));
    rlVertex3f(f32(x + w), f32(y + h), f32(0.0));
    rlVertex3f(f32(x + w), f32(y), f32(0.0));
    rlEnd();
}
