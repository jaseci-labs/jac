impl push_boom(w: &mut Game, x: float, y: float, z: float) {
    n = w.events.boom_n;
    if n >= MAX_EVENTS {
        return;
    }
    w.events.boom_x[n] = x;
    w.events.boom_y[n] = y;
    w.events.boom_z[n] = z;
    w.events.boom_n = n + 1;
}

impl push_kill(w: &mut Game, slot: int, gen: int, x: float, y: float, z: float) {
    n = w.events.kill_n;
    if n >= MAX_EVENTS {
        return;
    }
    w.events.kill_slot[n] = slot;
    w.events.kill_gen[n] = gen;
    w.events.kill_x[n] = x;
    w.events.kill_y[n] = y;
    w.events.kill_z[n] = z;
    w.events.kill_n = n + 1;
}

impl push_damage(w: &mut Game, amount: float) {
    n = w.events.dmg_n;
    if n >= MAX_EVENTS {
        return;
    }
    w.events.dmg[n] = amount;
    w.events.dmg_n = n + 1;
}

impl spawn_spark(
    w: &mut Game,
    x: float,
    y: float,
    z: float,
    vx: float,
    vy: float,
    vz: float,
    life: float,
    size: float,
    grav: float,
    cr: int,
    cg: int,
    cb: int
) {
    n = w.sparks.count;
    if n >= MAX_SPARKS {
        return;
    }
    w.sparks.x[n] = x;
    w.sparks.y[n] = y;
    w.sparks.z[n] = z;
    w.sparks.prev_x[n] = x;
    w.sparks.prev_y[n] = y;
    w.sparks.prev_z[n] = z;
    w.sparks.vx[n] = vx;
    w.sparks.vy[n] = vy;
    w.sparks.vz[n] = vz;
    w.sparks.life[n] = life;
    w.sparks.fade[n] = life;
    w.sparks.size[n] = size;
    w.sparks.grav[n] = grav;
    w.sparks.cr[n] = cr;
    w.sparks.cg[n] = cg;
    w.sparks.cb[n] = cb;
    w.sparks.count = n + 1;
}

impl spark_burst(
    w: &mut Game,
    x: float,
    y: float,
    z: float,
    n: int,
    speed: float,
    cr: int,
    cg: int,
    cb: int
) {
    for i in range(n) {
        a = rand_range(&mut w.rng, 0.0, 6.283);
        up = rand_range(&mut w.rng, 0.2, 1.0);
        s = rand_range(&mut w.rng, 0.3, 1.0) * speed;
        life = rand_range(&mut w.rng, 0.35, 0.8);
        size = rand_range(&mut w.rng, 0.08, 0.22);
        spawn_spark(
            w, x, y, z, jcos(a) * s, up * s, jsin(a) * s, life, size, 9.0, cr, cg, cb
        );
    }
}

impl remove_spark(w: &mut Game, i: int) {
    last = w.sparks.count - 1;
    w.sparks.x[i] = w.sparks.x[last];
    w.sparks.y[i] = w.sparks.y[last];
    w.sparks.z[i] = w.sparks.z[last];
    w.sparks.prev_x[i] = w.sparks.prev_x[last];
    w.sparks.prev_y[i] = w.sparks.prev_y[last];
    w.sparks.prev_z[i] = w.sparks.prev_z[last];
    w.sparks.vx[i] = w.sparks.vx[last];
    w.sparks.vy[i] = w.sparks.vy[last];
    w.sparks.vz[i] = w.sparks.vz[last];
    w.sparks.life[i] = w.sparks.life[last];
    w.sparks.fade[i] = w.sparks.fade[last];
    w.sparks.size[i] = w.sparks.size[last];
    w.sparks.grav[i] = w.sparks.grav[last];
    w.sparks.cr[i] = w.sparks.cr[last];
    w.sparks.cg[i] = w.sparks.cg[last];
    w.sparks.cb[i] = w.sparks.cb[last];
    w.sparks.count = last;
}

impl remove_rocket(w: &mut Game, i: int) {
    last = w.rockets.count - 1;
    w.rockets.x[i] = w.rockets.x[last];
    w.rockets.y[i] = w.rockets.y[last];
    w.rockets.z[i] = w.rockets.z[last];
    w.rockets.prev_x[i] = w.rockets.prev_x[last];
    w.rockets.prev_y[i] = w.rockets.prev_y[last];
    w.rockets.prev_z[i] = w.rockets.prev_z[last];
    w.rockets.vx[i] = w.rockets.vx[last];
    w.rockets.vy[i] = w.rockets.vy[last];
    w.rockets.vz[i] = w.rockets.vz[last];
    w.rockets.life[i] = w.rockets.life[last];
    w.rockets.count = last;
}

impl remove_shot(w: &mut Game, i: int) {
    last = w.shots.count - 1;
    w.shots.x[i] = w.shots.x[last];
    w.shots.y[i] = w.shots.y[last];
    w.shots.z[i] = w.shots.z[last];
    w.shots.prev_x[i] = w.shots.prev_x[last];
    w.shots.prev_y[i] = w.shots.prev_y[last];
    w.shots.prev_z[i] = w.shots.prev_z[last];
    w.shots.vx[i] = w.shots.vx[last];
    w.shots.vy[i] = w.shots.vy[last];
    w.shots.vz[i] = w.shots.vz[last];
    w.shots.life[i] = w.shots.life[last];
    w.shots.count = last;
}

impl respawn_enemy(w: &mut Game, i: int) {
    w.enemies.x[i] = rand_range(&mut w.rng, -14.0, 14.0);
    w.enemies.base_y[i] = rand_range(&mut w.rng, 1.2, 5.0);
    w.enemies.z[i] = rand_range(&mut w.rng, -16.0, 0.0);
    w.enemies.phase[i] = rand_range(&mut w.rng, 0.0, 6.28);
    w.enemies.y[i] = w.enemies.base_y[i];
    w.enemies.prev_x[i] = w.enemies.x[i];
    w.enemies.prev_y[i] = w.enemies.y[i];
    w.enemies.prev_z[i] = w.enemies.z[i];
    w.enemies.strafe_dir[i] = rand_sign(&mut w.rng);
    w.enemies.strafe_t[i] = rand_range(&mut w.rng, 1.0, 2.6);
    w.enemies.fire_t[i] = rand_range(&mut w.rng, 2.0, 5.0);
    w.enemies.charge[i] = 0.0;
    w.enemies.respawn_t[i] = 0.0;
    w.enemies.alive[i] = 1;
}

impl spawn_rocket(w: &mut Game) {
    n = w.rockets.count;
    if n >= MAX_ROCKETS {
        return;
    }
    yaw_r = w.player.yaw * DEG2RAD;
    pitch_r = w.player.pitch * DEG2RAD;
    cp = jcos(pitch_r);
    dx = -jsin(yaw_r) * cp;
    dy = jsin(pitch_r);
    dz = -jcos(yaw_r) * cp;
    w.rockets.x[n] = w.player.x + dx * 1.2;
    w.rockets.y[n] = w.player.y - 0.25 + dy * 1.2;
    w.rockets.z[n] = w.player.z + dz * 1.2;
    w.rockets.prev_x[n] = w.rockets.x[n];
    w.rockets.prev_y[n] = w.rockets.y[n];
    w.rockets.prev_z[n] = w.rockets.z[n];
    w.rockets.vx[n] = dx * ROCKET_SPEED;
    w.rockets.vy[n] = dy * ROCKET_SPEED;
    w.rockets.vz[n] = dz * ROCKET_SPEED;
    w.rockets.life[n] = ROCKET_LIFE;
    w.rockets.count = n + 1;
    w.player.fire_cd = FIRE_COOLDOWN;
    w.player.kick_t = 0.22;
    w.player.muzzle_t = 0.07;
}

impl spawn_shot(w: &mut Game, ex: float, ey: float, ez: float) {
    n = w.shots.count;
    if n >= MAX_SHOTS {
        return;
    }
    tx = w.player.x + rand_range(&mut w.rng, -1.4, 1.4);
    ty = w.player.y + rand_range(&mut w.rng, -0.7, 0.7);
    tz = w.player.z + rand_range(&mut w.rng, -1.4, 1.4);
    dx = tx - ex;
    dy = ty - ey;
    dz = tz - ez;
    d = jsqrt(dx * dx + dy * dy + dz * dz);
    if d < 0.01 {
        return;
    }
    w.shots.x[n] = ex;
    w.shots.y[n] = ey;
    w.shots.z[n] = ez;
    w.shots.prev_x[n] = ex;
    w.shots.prev_y[n] = ey;
    w.shots.prev_z[n] = ez;
    w.shots.vx[n] = dx / d * SHOT_SPEED;
    w.shots.vy[n] = dy / d * SHOT_SPEED;
    w.shots.vz[n] = dz / d * SHOT_SPEED;
    w.shots.life[n] = SHOT_LIFE;
    w.shots.count = n + 1;
}

impl store_prev(w: &mut Game) {
    w.player.prev_x = w.player.x;
    w.player.prev_y = w.player.y;
    w.player.prev_z = w.player.z;
    for i in range(MAX_ENEMIES) {
        w.enemies.prev_x[i] = w.enemies.x[i];
        w.enemies.prev_y[i] = w.enemies.y[i];
        w.enemies.prev_z[i] = w.enemies.z[i];
    }
    rn = w.rockets.count;
    for i in range(rn) {
        w.rockets.prev_x[i] = w.rockets.x[i];
        w.rockets.prev_y[i] = w.rockets.y[i];
        w.rockets.prev_z[i] = w.rockets.z[i];
    }
    sn = w.shots.count;
    for i in range(sn) {
        w.shots.prev_x[i] = w.shots.x[i];
        w.shots.prev_y[i] = w.shots.y[i];
        w.shots.prev_z[i] = w.shots.z[i];
    }
    pn = w.sparks.count;
    for i in range(pn) {
        w.sparks.prev_x[i] = w.sparks.x[i];
        w.sparks.prev_y[i] = w.sparks.y[i];
        w.sparks.prev_z[i] = w.sparks.z[i];
    }
}

impl tick_player(w: &mut Game) {
    w.player.fire_cd -= TICK_DT;
    if w.player.hurt_t > 0.0 {
        w.player.hurt_t -= TICK_DT;
    }
    if w.player.invuln_t > 0.0 {
        w.player.invuln_t -= TICK_DT;
    }
    if w.player.kick_t > 0.0 {
        w.player.kick_t -= TICK_DT;
    }
    if w.player.muzzle_t > 0.0 {
        w.player.muzzle_t -= TICK_DT;
    }
    w.player.safe_t += TICK_DT;
    if w.player.safe_t > HP_REGEN_DELAY and w.player.hp < HP_MAX {
        w.player.hp += HP_REGEN_RATE * TICK_DT;
        if w.player.hp > HP_MAX {
            w.player.hp = HP_MAX;
        }
    }

    w.player.yaw = w.cmd.yaw;
    w.player.pitch = w.cmd.pitch;

    mf = w.cmd.move_fwd;
    ms = w.cmd.move_side;
    ml = jsqrt(mf * mf + ms * ms);
    if ml > 1.0 {
        mf = mf / ml;
        ms = ms / ml;
    }
    yaw_r = w.player.yaw * DEG2RAD;
    fwd_x = -jsin(yaw_r);
    fwd_z = -jcos(yaw_r);
    rgt_x = jcos(yaw_r);
    rgt_z = -jsin(yaw_r);
    w.player.x += (fwd_x * mf + rgt_x * ms) * MOVE_SPEED * TICK_DT;
    w.player.z += (fwd_z * mf + rgt_z * ms) * MOVE_SPEED * TICK_DT;

    if w.cmd.fire and w.player.fire_cd <= 0.0 {
        spawn_rocket(w);
    }
}

impl tick_enemies(w: &mut Game) {
    for i in range(MAX_ENEMIES) {
        if w.enemies.alive[i] == 1 {
            w.enemies.y[i] = w.enemies.base_y[i]
                + 0.4 * jsin(w.time * 1.5 + w.enemies.phase[i]);

            dx = w.player.x - w.enemies.x[i];
            dz = w.player.z - w.enemies.z[i];
            dist = jsqrt(dx * dx + dz * dz);
            if dist > 0.5 {
                nx = dx / dist;
                nz = dz / dist;

                w.enemies.strafe_t[i] -= TICK_DT;
                if w.enemies.strafe_t[i] <= 0.0 {
                    w.enemies.strafe_dir[i] = rand_sign(&mut w.rng);
                    w.enemies.strafe_t[i] = rand_range(&mut w.rng, 1.0, 2.6);
                }
                w.enemies.x[i] += -nz
                    * w.enemies.strafe_dir[i]
                    * ENEMY_STRAFE_SPEED
                    * TICK_DT;
                w.enemies.z[i] += nx
                    * w.enemies.strafe_dir[i]
                    * ENEMY_STRAFE_SPEED
                    * TICK_DT;

                if dist > ENEMY_FAR_DIST {
                    w.enemies.x[i] += nx * ENEMY_ADVANCE_SPEED * TICK_DT;
                    w.enemies.z[i] += nz * ENEMY_ADVANCE_SPEED * TICK_DT;
                } elif dist < ENEMY_NEAR_DIST {
                    w.enemies.x[i] -= nx * ENEMY_RETREAT_SPEED * TICK_DT;
                    w.enemies.z[i] -= nz * ENEMY_RETREAT_SPEED * TICK_DT;
                }
            }

            if w.enemies.x[i] > ARENA_HALF_X {
                w.enemies.x[i] = ARENA_HALF_X;
            }
            if w.enemies.x[i] < -ARENA_HALF_X {
                w.enemies.x[i] = -ARENA_HALF_X;
            }
            if w.enemies.z[i] > ARENA_Z_NEAR {
                w.enemies.z[i] = ARENA_Z_NEAR;
            }
            if w.enemies.z[i] < ARENA_Z_FAR {
                w.enemies.z[i] = ARENA_Z_FAR;
            }

            w.enemies.fire_t[i] -= TICK_DT;
            if w.enemies.fire_t[i] <= 0.0 and dist < ENEMY_SIGHT_DIST {
                w.enemies.charge[i] += TICK_DT;
                if w.enemies.charge[i] >= CHARGE_T {
                    spawn_shot(w, w.enemies.x[i], w.enemies.y[i], w.enemies.z[i]);
                    w.enemies.charge[i] = 0.0;
                    w.enemies.fire_t[i] = rand_range(&mut w.rng, 2.8, 5.4);
                }
            }
        } else {
            w.enemies.respawn_t[i] -= TICK_DT;
            if w.enemies.respawn_t[i] <= 0.0 {
                respawn_enemy(w, i);
            }
        }
    }
}

impl tick_rockets(w: &mut Game) {
    i = 0;
    while i < w.rockets.count {
        w.rockets.x[i] += w.rockets.vx[i] * TICK_DT;
        w.rockets.y[i] += w.rockets.vy[i] * TICK_DT;
        w.rockets.z[i] += w.rockets.vz[i] * TICK_DT;
        w.rockets.life[i] -= TICK_DT;
        rx = w.rockets.x[i];
        ry = w.rockets.y[i];
        rz = w.rockets.z[i];
        svx = rand_range(&mut w.rng, -0.4, 0.4);
        svy = rand_range(&mut w.rng, 0.1, 0.6);
        svz = rand_range(&mut w.rng, -0.4, 0.4);
        spawn_spark(w, rx, ry, rz, svx, svy, svz, 0.35, 0.1, -0.6, 120, 122, 130);
        boom = False;
        if ry <= 0.1 {
            boom = True;
        }
        if w.rockets.life[i] <= 0.0 {
            boom = True;
        }
        for ti in range(MAX_ENEMIES) {
            if w.enemies.alive[ti] == 1 and not boom {
                ddx = rx - w.enemies.x[ti];
                ddy = ry - w.enemies.y[ti];
                ddz = rz - w.enemies.z[ti];
                if ddx * ddx + ddy * ddy + ddz * ddz < ROCKET_HIT_R2 {
                    boom = True;
                }
            }
        }
        if boom {
            push_boom(w, rx, ry, rz);
            remove_rocket(w, i);
        } else {
            i += 1;
        }
    }
}

impl tick_shots(w: &mut Game) {
    i = 0;
    while i < w.shots.count {
        w.shots.x[i] += w.shots.vx[i] * TICK_DT;
        w.shots.y[i] += w.shots.vy[i] * TICK_DT;
        w.shots.z[i] += w.shots.vz[i] * TICK_DT;
        w.shots.life[i] -= TICK_DT;
        gone = False;
        if w.shots.life[i] <= 0.0 {
            gone = True;
        } elif w.shots.y[i] < 0.05 {
            spark_burst(w, w.shots.x[i], 0.1, w.shots.z[i], 3, 2.0, 150, 90, 200);
            gone = True;
        } else {
            ddx = w.shots.x[i] - w.player.x;
            ddy = w.shots.y[i] - w.player.y;
            ddz = w.shots.z[i] - w.player.z;
            if ddx * ddx + ddy * ddy + ddz * ddz < SHOT_HIT_R2 {
                push_damage(w, SHOT_DAMAGE);
                gone = True;
            }
        }
        if gone {
            remove_shot(w, i);
        } else {
            i += 1;
        }
    }
}

impl tick_sparks(w: &mut Game) {
    i = 0;
    while i < w.sparks.count {
        w.sparks.x[i] += w.sparks.vx[i] * TICK_DT;
        w.sparks.y[i] += w.sparks.vy[i] * TICK_DT;
        w.sparks.z[i] += w.sparks.vz[i] * TICK_DT;
        w.sparks.vy[i] -= w.sparks.grav[i] * TICK_DT;
        if w.sparks.y[i] < 0.05 and w.sparks.grav[i] > 0.0 {
            w.sparks.y[i] = 0.05;
            w.sparks.vy[i] = -w.sparks.vy[i] * 0.35;
            w.sparks.vx[i] = w.sparks.vx[i] * 0.7;
            w.sparks.vz[i] = w.sparks.vz[i] * 0.7;
        }
        w.sparks.life[i] -= TICK_DT;
        if w.sparks.life[i] <= 0.0 {
            remove_spark(w, i);
        } else {
            i += 1;
        }
    }
}

impl apply_damage(w: &mut Game, amount: float) {
    if w.player.invuln_t > 0.0 {
        return;
    }
    w.player.hp -= amount;
    w.player.hurt_t = HURT_FLASH_T;
    w.player.safe_t = 0.0;
    if w.player.hp <= 0.0 {
        w.stats.deaths += 1;
        w.player.hp = HP_MAX;
        w.player.invuln_t = DEATH_INVULN_T;
        w.player.x = SPAWN_X;
        w.player.y = SPAWN_Y;
        w.player.z = SPAWN_Z;
        w.player.prev_x = SPAWN_X;
        w.player.prev_y = SPAWN_Y;
        w.player.prev_z = SPAWN_Z;
    }
}

impl process_events(w: &mut Game) {
    bi = 0;
    while bi < w.events.boom_n {
        bx = w.events.boom_x[bi];
        `by = w.events.boom_y[bi];
        bz = w.events.boom_z[bi];
        for ei in range(MAX_ENEMIES) {
            if w.enemies.alive[ei] == 1 {
                ddx = w.enemies.x[ei] - bx;
                ddy = w.enemies.y[ei] - `by;
                ddz = w.enemies.z[ei] - bz;
                if ddx * ddx + ddy * ddy + ddz * ddz < BLAST_R2 {
                    push_kill(
                        w,
                        ei,
                        w.enemies.gen[ei],
                        w.enemies.x[ei],
                        w.enemies.y[ei],
                        w.enemies.z[ei]
                    );
                }
            }
        }
        spark_burst(w, bx, `by, bz, 10, 6.0, 255, 150, 60);
        spark_burst(w, bx, `by, bz, 6, 3.5, 255, 220, 120);
        spawn_spark(w, bx, `by, bz, 0.0, 0.6, 0.0, 0.28, 0.9, -0.5, 255, 235, 160);
        bi += 1;
    }
    w.events.boom_n = 0;

    ki = 0;
    while ki < w.events.kill_n {
        slot = w.events.kill_slot[ki];
        if w.enemies.alive[slot] == 1
            and w.enemies.gen[slot] == w.events.kill_gen[ki] {
            w.enemies.alive[slot] = 0;
            w.enemies.gen[slot] += 1;
            w.enemies.respawn_t[slot] = rand_range(&mut w.rng, 1.2, 2.6);
            w.stats.score += 1;
            kx = w.events.kill_x[ki];
            ky = w.events.kill_y[ki];
            kz = w.events.kill_z[ki];
            spark_burst(w, kx, ky, kz, 12, 7.0, 235, 90, 60);
            spark_burst(w, kx, ky, kz, 5, 4.0, 255, 210, 110);
        }
        ki += 1;
    }
    w.events.kill_n = 0;

    di = 0;
    while di < w.events.dmg_n {
        apply_damage(w, w.events.dmg[di]);
        di += 1;
    }
    w.events.dmg_n = 0;
}

impl sim_tick(w: &mut Game) {
    store_prev(w);
    w.time += TICK_DT;
    tick_player(w);
    tick_enemies(w);
    tick_rockets(w);
    tick_shots(w);
    tick_sparks(w);
    process_events(w);
}

impl world_new -> Game {
    w: own Game = Game();
    for i in range(MAX_ENEMIES) {
        w.enemies.x.append(0.0);
        w.enemies.y.append(0.0);
        w.enemies.z.append(0.0);
        w.enemies.prev_x.append(0.0);
        w.enemies.prev_y.append(0.0);
        w.enemies.prev_z.append(0.0);
        w.enemies.base_y.append(0.0);
        w.enemies.phase.append(0.0);
        w.enemies.strafe_dir.append(1.0);
        w.enemies.strafe_t.append(0.0);
        w.enemies.fire_t.append(0.0);
        w.enemies.charge.append(0.0);
        w.enemies.respawn_t.append(0.0);
        w.enemies.alive.append(0);
        w.enemies.gen.append(0);
    }
    for i in range(MAX_ROCKETS) {
        w.rockets.x.append(0.0);
        w.rockets.y.append(0.0);
        w.rockets.z.append(0.0);
        w.rockets.prev_x.append(0.0);
        w.rockets.prev_y.append(0.0);
        w.rockets.prev_z.append(0.0);
        w.rockets.vx.append(0.0);
        w.rockets.vy.append(0.0);
        w.rockets.vz.append(0.0);
        w.rockets.life.append(0.0);
    }
    for i in range(MAX_SHOTS) {
        w.shots.x.append(0.0);
        w.shots.y.append(0.0);
        w.shots.z.append(0.0);
        w.shots.prev_x.append(0.0);
        w.shots.prev_y.append(0.0);
        w.shots.prev_z.append(0.0);
        w.shots.vx.append(0.0);
        w.shots.vy.append(0.0);
        w.shots.vz.append(0.0);
        w.shots.life.append(0.0);
    }
    for i in range(MAX_SPARKS) {
        w.sparks.x.append(0.0);
        w.sparks.y.append(0.0);
        w.sparks.z.append(0.0);
        w.sparks.prev_x.append(0.0);
        w.sparks.prev_y.append(0.0);
        w.sparks.prev_z.append(0.0);
        w.sparks.vx.append(0.0);
        w.sparks.vy.append(0.0);
        w.sparks.vz.append(0.0);
        w.sparks.life.append(0.0);
        w.sparks.fade.append(1.0);
        w.sparks.size.append(0.1);
        w.sparks.grav.append(9.0);
        w.sparks.cr.append(255);
        w.sparks.cg.append(255);
        w.sparks.cb.append(255);
    }
    for i in range(MAX_EVENTS) {
        w.events.boom_x.append(0.0);
        w.events.boom_y.append(0.0);
        w.events.boom_z.append(0.0);
        w.events.kill_slot.append(0);
        w.events.kill_gen.append(0);
        w.events.kill_x.append(0.0);
        w.events.kill_y.append(0.0);
        w.events.kill_z.append(0.0);
        w.events.dmg.append(0.0);
    }
    for i in range(MAX_ENEMIES) {
        respawn_enemy(&mut w, i);
    }
    return w;
}
