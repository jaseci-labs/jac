impl sample_input(w: &mut Game, dtf: float) {
    turn = 90.0 * dtf;

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
        w.cmd.yaw += turn;
    }
    if key_held(KEY_RIGHT) {
        w.cmd.yaw -= turn;
    }
    if key_held(KEY_UP) {
        w.cmd.pitch += turn;
    }
    if key_held(KEY_DOWN) {
        w.cmd.pitch -= turn;
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
                w.cmd.yaw -= ddx * mouse_sens;
                w.cmd.pitch -= ddy * mouse_sens;
            }
        }
        prev_mx = mx;
        prev_my = my;
    }

    w.cmd.pitch = clampf(w.cmd.pitch, -PITCH_LIMIT, PITCH_LIMIT);

    mf = 0.0;
    if key_held(KEY_W) {
        mf += 1.0;
    }
    if key_held(KEY_S) {
        mf -= 1.0;
    }
    ms = 0.0;
    if key_held(KEY_D) {
        ms += 1.0;
    }
    if key_held(KEY_A) {
        ms -= 1.0;
    }
    w.cmd.move_fwd = mf;
    w.cmd.move_side = ms;
    w.cmd.fire = key_held(KEY_SPACE) or (mouse_captured and mouse_pressed(MOUSE_LEFT));
}

impl draw_enemy_model(ex: float, ey: float, ez: float, k: float) {
    r = 200;
    g = 60;
    b = 50;
    if k > 0.66 {
        r = 255;
        g = 215;
        b = 90;
    } elif k > 0.33 {
        r = 240;
        g = 140;
        b = 70;
    }
    s = 1.3 + 0.18 * k;
    draw_box(ex, ey, ez, s, s, s, r, g, b);
    draw_box(ex, ey + 0.75, ez, 0.28, 0.42, 0.9, r, g, b);
    draw_box(ex - 0.85, ey, ez, 0.34, 0.34, 0.34, 150, 45, 40);
    draw_box(ex + 0.85, ey, ez, 0.34, 0.34, 0.34, 150, 45, 40);
}

impl draw_enemies(w: &Game, alpha: float) {
    for i in range(MAX_ENEMIES) {
        if w.enemies.alive[i] == 1 {
            draw_enemy_model(
                lerp(w.enemies.prev_x[i], w.enemies.x[i], alpha),
                lerp(w.enemies.prev_y[i], w.enemies.y[i], alpha),
                lerp(w.enemies.prev_z[i], w.enemies.z[i], alpha),
                w.enemies.charge[i] / CHARGE_T
            );
        }
    }
}

impl draw_rockets(w: &Game, alpha: float) {
    n = w.rockets.count;
    for i in range(n) {
        rx = lerp(w.rockets.prev_x[i], w.rockets.x[i], alpha);
        ry = lerp(w.rockets.prev_y[i], w.rockets.y[i], alpha);
        rz = lerp(w.rockets.prev_z[i], w.rockets.z[i], alpha);
        draw_box(rx, ry, rz, 0.16, 0.16, 0.42, 205, 206, 212);
        draw_box(rx, ry, rz - 0.26, 0.11, 0.11, 0.12, 255, 140, 60);
    }
}

impl draw_shots(w: &Game, alpha: float, rt: float) {
    n = w.shots.count;
    for i in range(n) {
        s = 0.26 + 0.06 * jsin(rt * 22.0 + float(i));
        draw_box(
            lerp(w.shots.prev_x[i], w.shots.x[i], alpha),
            lerp(w.shots.prev_y[i], w.shots.y[i], alpha),
            lerp(w.shots.prev_z[i], w.shots.z[i], alpha),
            s,
            s,
            s,
            190,
            90,
            255
        );
    }
}

impl draw_sparks(w: &Game, alpha: float) {
    n = w.sparks.count;
    for i in range(n) {
        ps = w.sparks.size[i] * (w.sparks.life[i] / w.sparks.fade[i]);
        draw_box(
            lerp(w.sparks.prev_x[i], w.sparks.x[i], alpha),
            lerp(w.sparks.prev_y[i], w.sparks.y[i], alpha),
            lerp(w.sparks.prev_z[i], w.sparks.z[i], alpha),
            ps,
            ps,
            ps,
            w.sparks.cr[i],
            w.sparks.cg[i],
            w.sparks.cb[i]
        );
    }
}

impl draw_weapon(w: &Game, cx: float, cy: float, cz: float, rt: float) {
    begin_model(cx, cy, cz, w.cmd.yaw, w.cmd.pitch);

    wob = jsin(rt * 2.1) * 0.008;
    kz = w.player.kick_t * 0.5;

    draw_box(0.34, -0.27 + wob, -0.94 + kz, 0.10, 0.10, 0.60, 66, 68, 78);
    draw_box(0.34, -0.27 + wob, -1.27 + kz, 0.14, 0.14, 0.08, 42, 43, 50);
    draw_box(0.34, -0.27 + wob, -1.32 + kz, 0.07, 0.07, 0.07, 255, 140, 60);
    draw_box(0.34, -0.37 + wob, -0.74 + kz, 0.045, 0.13, 0.075, 48, 48, 55);
    draw_box(0.34, -0.195 + wob, -1.05 + kz, 0.02, 0.04, 0.028, 90, 92, 102);

    if w.player.muzzle_t > 0.0 {
        fs = 0.34 * (w.player.muzzle_t / 0.07);
        draw_box(0.34, -0.27 + wob, -1.45 + kz, fs, fs, fs, 255, 235, 140);
    }
    end_model();
}

impl draw_hud(w: &Game, rt: float) {
    ccx = SCREEN_W * 0.5;
    ccy = SCREEN_H * 0.5;
    gap = 6.0 + w.player.kick_t * 40.0;
    draw_rect2d(ccx - gap - 10.0, ccy - 1.0, 10.0, 2.0, 215, 220, 230);
    draw_rect2d(ccx + gap, ccy - 1.0, 10.0, 2.0, 215, 220, 230);
    draw_rect2d(ccx - 1.0, ccy - gap - 10.0, 2.0, 10.0, 215, 220, 230);
    draw_rect2d(ccx - 1.0, ccy + gap, 2.0, 10.0, 215, 220, 230);

    if w.player.fire_cd > 0.0 {
        cdk = 1.0 - w.player.fire_cd / FIRE_COOLDOWN;
        draw_rect2d(ccx - 20.0, ccy + 18.0, 40.0 * cdk, 3.0, 255, 150, 60);
    }

    bar_y = SCREEN_H - 40.0;
    draw_rect2d(24.0, bar_y, 244.0, 20.0, 26, 28, 34);
    hpk = w.player.hp / HP_MAX;
    fr = 90;
    fg = 220;
    fb = 120;
    if hpk < 0.25 {
        fr = 240;
        fg = 80;
        fb = 70;
    } elif hpk < 0.5 {
        fr = 250;
        fg = 200;
        fb = 80;
    }
    if w.player.invuln_t > 0.0 and jsin(rt * 18.0) > 0.0 {
        fr = 160;
        fg = 170;
        fb = 190;
    }
    draw_rect2d(27.0, bar_y + 3.0, 238.0 * hpk, 14.0, fr, fg, fb);

    if w.player.hurt_t > 0.0 {
        draw_rect2d(0.0, 0.0, SCREEN_W, 6.0, 205, 60, 50);
        draw_rect2d(0.0, SCREEN_H - 6.0, SCREEN_W, 6.0, 205, 60, 50);
        draw_rect2d(0.0, 0.0, 6.0, SCREEN_H, 205, 60, 50);
        draw_rect2d(SCREEN_W - 6.0, 0.0, 6.0, SCREEN_H, 205, 60, 50);
    }
}

impl render(w: &Game, alpha: float) {
    rt = w.time + (alpha - 1.0) * TICK_DT;
    cx = lerp(w.player.prev_x, w.player.x, alpha);
    cy = lerp(w.player.prev_y, w.player.y, alpha);
    cz = lerp(w.player.prev_z, w.player.z, alpha);

    begin_frame(16, 16, 18);
    set_camera(cx, cy, cz, w.cmd.yaw, w.cmd.pitch, SCREEN_W / SCREEN_H);
    draw_floor(20, 1.5);
    draw_enemies(w, alpha);
    draw_rockets(w, alpha);
    draw_shots(w, alpha, rt);
    draw_sparks(w, alpha);
    draw_weapon(w, cx, cy, cz, rt);
    begin_overlay(SCREEN_W, SCREEN_H);
    draw_hud(w, rt);
    draw_fps(10, 10);
    end_frame();
}

impl init -> Game {
    open_window();
    return world_new();
}

impl frame(w: &mut Game) -> bool {
    dtf = frame_dt();
    if dtf > 0.05 {
        dtf = 0.05;
    }
    sample_input(w, dtf);
    acc += dtf;
    if acc > TICK_MAX_CATCHUP {
        acc = TICK_MAX_CATCHUP;
    }
    while acc >= TICK_DT {
        sim_tick(w);
        acc -= TICK_DT;
    }
    render(w, acc / TICK_DT);
    return should_close();
}
