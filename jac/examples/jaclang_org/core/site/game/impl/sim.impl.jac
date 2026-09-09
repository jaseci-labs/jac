impl push_boom(w: &mut Game, x: float, y: float, z: float) {
    w.events.boom(x, y, z);
}

impl push_kill(w: &mut Game, slot: int, gen: int, x: float, y: float, z: float) {
    w.events.kill(slot, gen, x, y, z);
}

impl push_damage(w: &mut Game, amount: float) {
    w.events.hurt(amount);
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
    n = w.sparks.size();
    if n >= MAX_SPARKS {
        return;
    }
    item = Spark();
    item.x = x;
    item.y = y;
    item.z = z;
    item.prev_x = x;
    item.prev_y = y;
    item.prev_z = z;
    item.vx = vx;
    item.vy = vy;
    item.vz = vz;
    item.life = life;
    item.fade = life;
    item.size = size;
    item.grav = grav;
    item.cr = cr;
    item.cg = cg;
    item.cb = cb;
    w.sparks.items.append(item);
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
    w.sparks.remove(i);
}

impl remove_rocket(w: &mut Game, i: int) {
    w.rockets.remove(i);
}

impl remove_shot(w: &mut Game, i: int) {
    w.shots.remove(i);
}

impl respawn_enemy(w: &mut Game, i: int) {
    w.enemies.items[i].x = rand_range(&mut w.rng, -14.0, 14.0);
    w.enemies.items[i].base_y = rand_range(&mut w.rng, 1.2, 5.0);
    w.enemies.items[i].z = rand_range(&mut w.rng, -16.0, 0.0);
    w.enemies.items[i].phase = rand_range(&mut w.rng, 0.0, 6.28);
    w.enemies.items[i].y = w.enemies.items[i].base_y;
    w.enemies.items[i].prev_x = w.enemies.items[i].x;
    w.enemies.items[i].prev_y = w.enemies.items[i].y;
    w.enemies.items[i].prev_z = w.enemies.items[i].z;
    w.enemies.items[i].strafe_dir = rand_sign(&mut w.rng);
    w.enemies.items[i].strafe_t = rand_range(&mut w.rng, 1.0, 2.6);
    w.enemies.items[i].fire_t = rand_range(&mut w.rng, 2.0, 5.0);
    w.enemies.items[i].charge = 0.0;
    w.enemies.items[i].respawn_t = 0.0;
    w.enemies.items[i].alive = 1;
}

impl spawn_rocket(w: &mut Game) {
    n = w.rockets.size();
    if n >= MAX_ROCKETS {
        return;
    }
    yaw_r = w.player.yaw * DEG2RAD;
    pitch_r = w.player.pitch * DEG2RAD;
    cp = jcos(pitch_r);
    dx = -jsin(yaw_r) * cp;
    dy = jsin(pitch_r);
    dz = -jcos(yaw_r) * cp;
    item = Projectile();
    item.x = w.player.x + dx * 1.2;
    item.y = w.player.y - 0.25 + dy * 1.2;
    item.z = w.player.z + dz * 1.2;
    item.prev_x = item.x;
    item.prev_y = item.y;
    item.prev_z = item.z;
    item.vx = dx * ROCKET_SPEED;
    item.vy = dy * ROCKET_SPEED;
    item.vz = dz * ROCKET_SPEED;
    item.life = ROCKET_LIFE;
    w.rockets.items.append(item);
    w.player.fire_cd = FIRE_COOLDOWN;
    w.player.kick_t = 0.22;
    w.player.muzzle_t = 0.07;
}

impl spawn_shot(w: &mut Game, ex: float, ey: float, ez: float) {
    n = w.shots.size();
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
    item = Projectile();
    item.x = ex;
    item.y = ey;
    item.z = ez;
    item.prev_x = ex;
    item.prev_y = ey;
    item.prev_z = ez;
    item.vx = dx / d * SHOT_SPEED;
    item.vy = dy / d * SHOT_SPEED;
    item.vz = dz / d * SHOT_SPEED;
    item.life = SHOT_LIFE;
    w.shots.items.append(item);
}

impl store_prev(w: &mut Game) {
    w.player.prev_x = w.player.x;
    w.player.prev_y = w.player.y;
    w.player.prev_z = w.player.z;
    for i in range(MAX_ENEMIES) {
        w.enemies.items[i].prev_x = w.enemies.items[i].x;
        w.enemies.items[i].prev_y = w.enemies.items[i].y;
        w.enemies.items[i].prev_z = w.enemies.items[i].z;
    }
    rn = w.rockets.size();
    for i in range(rn) {
        w.rockets.items[i].prev_x = w.rockets.items[i].x;
        w.rockets.items[i].prev_y = w.rockets.items[i].y;
        w.rockets.items[i].prev_z = w.rockets.items[i].z;
    }
    sn = w.shots.size();
    for i in range(sn) {
        w.shots.items[i].prev_x = w.shots.items[i].x;
        w.shots.items[i].prev_y = w.shots.items[i].y;
        w.shots.items[i].prev_z = w.shots.items[i].z;
    }
    pn = w.sparks.size();
    for i in range(pn) {
        w.sparks.items[i].prev_x = w.sparks.items[i].x;
        w.sparks.items[i].prev_y = w.sparks.items[i].y;
        w.sparks.items[i].prev_z = w.sparks.items[i].z;
    }
}

impl Player.tick(cmd: &mut Cmd) -> bool {
    self.fire_cd -= TICK_DT;
    if self.hurt_t > 0.0 {
        self.hurt_t -= TICK_DT;
    }
    if self.invuln_t > 0.0 {
        self.invuln_t -= TICK_DT;
    }
    if self.kick_t > 0.0 {
        self.kick_t -= TICK_DT;
    }
    if self.muzzle_t > 0.0 {
        self.muzzle_t -= TICK_DT;
    }
    self.safe_t += TICK_DT;
    if self.safe_t > HP_REGEN_DELAY and self.hp < HP_MAX {
        self.hp += HP_REGEN_RATE * TICK_DT;
        if self.hp > HP_MAX {
            self.hp = HP_MAX;
        }
    }

    self.yaw = cmd.yaw;
    self.pitch = cmd.pitch;

    mf = cmd.move_fwd;
    ms = cmd.move_side;
    ml = jsqrt(mf * mf + ms * ms);
    if ml > 1.0 {
        mf = mf / ml;
        ms = ms / ml;
    }
    yaw_r = self.yaw * DEG2RAD;
    fwd_x = -jsin(yaw_r);
    fwd_z = -jcos(yaw_r);
    rgt_x = jcos(yaw_r);
    rgt_z = -jsin(yaw_r);
    self.x += (fwd_x * mf + rgt_x * ms) * MOVE_SPEED * TICK_DT;
    self.z += (fwd_z * mf + rgt_z * ms) * MOVE_SPEED * TICK_DT;

    if cmd.jump and self.grounded {
        self.vy = JUMP_SPEED;
        self.grounded = False;
    }
    cmd.jump = False;
    if not self.grounded {
        self.vy -= GRAVITY * TICK_DT;
        self.y += self.vy * TICK_DT;
        if self.y <= SPAWN_Y {
            self.y = SPAWN_Y;
            self.vy = 0.0;
            self.grounded = True;
        }
    }
    firing = cmd.fire and self.fire_cd <= 0.0;
    cmd.fire = False;
    return firing;
}

impl tick_player(w: &mut Game) {
    if w.player.tick(&mut w.cmd) {
        spawn_rocket(w);
    }
}

impl tick_enemies(w: &mut Game) {
    for i in range(MAX_ENEMIES) {
        if w.enemies.items[i].alive == 1 {
            w.enemies.items[i].y = w.enemies.items[i].base_y
                + 0.4 * jsin(w.time * 1.5 + w.enemies.items[i].phase);

            dx = w.player.x - w.enemies.items[i].x;
            dz = w.player.z - w.enemies.items[i].z;
            dist = jsqrt(dx * dx + dz * dz);
            if dist > 0.5 {
                nx = dx / dist;
                nz = dz / dist;

                w.enemies.items[i].strafe_t -= TICK_DT;
                if w.enemies.items[i].strafe_t <= 0.0 {
                    w.enemies.items[i].strafe_dir = rand_sign(&mut w.rng);
                    w.enemies.items[i].strafe_t = rand_range(&mut w.rng, 1.0, 2.6);
                }
                w.enemies.items[i].x += -nz
                    * w.enemies.items[i].strafe_dir
                    * ENEMY_STRAFE_SPEED
                    * TICK_DT;
                w.enemies.items[i].z += nx
                    * w.enemies.items[i].strafe_dir
                    * ENEMY_STRAFE_SPEED
                    * TICK_DT;

                if dist > ENEMY_FAR_DIST {
                    w.enemies.items[i].x += nx * ENEMY_ADVANCE_SPEED * TICK_DT;
                    w.enemies.items[i].z += nz * ENEMY_ADVANCE_SPEED * TICK_DT;
                } elif dist < ENEMY_NEAR_DIST {
                    w.enemies.items[i].x -= nx * ENEMY_RETREAT_SPEED * TICK_DT;
                    w.enemies.items[i].z -= nz * ENEMY_RETREAT_SPEED * TICK_DT;
                }
            }

            if w.enemies.items[i].x > ARENA_HALF_X {
                w.enemies.items[i].x = ARENA_HALF_X;
            }
            if w.enemies.items[i].x < -ARENA_HALF_X {
                w.enemies.items[i].x = -ARENA_HALF_X;
            }
            if w.enemies.items[i].z > ARENA_Z_NEAR {
                w.enemies.items[i].z = ARENA_Z_NEAR;
            }
            if w.enemies.items[i].z < ARENA_Z_FAR {
                w.enemies.items[i].z = ARENA_Z_FAR;
            }

            w.enemies.items[i].fire_t -= TICK_DT;
            if w.enemies.items[i].fire_t <= 0.0 and dist < ENEMY_SIGHT_DIST {
                w.enemies.items[i].charge += TICK_DT;
                if w.enemies.items[i].charge >= CHARGE_T {
                    spawn_shot(
                        w,
                        w.enemies.items[i].x,
                        w.enemies.items[i].y,
                        w.enemies.items[i].z
                    );
                    w.enemies.items[i].charge = 0.0;
                    w.enemies.items[i].fire_t = rand_range(&mut w.rng, 2.8, 5.4);
                }
            }
        } else {
            w.enemies.items[i].respawn_t -= TICK_DT;
            if w.enemies.items[i].respawn_t <= 0.0 {
                respawn_enemy(w, i);
            }
        }
    }
}

impl tick_rockets(w: &mut Game) {
    i = 0;
    while i < w.rockets.size() {
        w.rockets.items[i].step();
        rx = w.rockets.items[i].x;
        ry = w.rockets.items[i].y;
        rz = w.rockets.items[i].z;
        svx = rand_range(&mut w.rng, -0.4, 0.4);
        svy = rand_range(&mut w.rng, 0.1, 0.6);
        svz = rand_range(&mut w.rng, -0.4, 0.4);
        spawn_spark(w, rx, ry, rz, svx, svy, svz, 0.35, 0.1, -0.6, 120, 122, 130);
        boom = False;
        if ry <= 0.1 {
            boom = True;
        }
        if w.rockets.items[i].life <= 0.0 {
            boom = True;
        }
        for ti in range(MAX_ENEMIES) {
            if w.enemies.items[ti].alive == 1 and not boom {
                ddx = rx - w.enemies.items[ti].x;
                ddy = ry - w.enemies.items[ti].y;
                ddz = rz - w.enemies.items[ti].z;
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
    while i < w.shots.size() {
        w.shots.items[i].step();
        gone = False;
        if w.shots.items[i].life <= 0.0 {
            gone = True;
        } elif w.shots.items[i].y < 0.05 {
            spark_burst(
                w, w.shots.items[i].x, 0.1, w.shots.items[i].z, 3, 2.0, 150, 90, 200
            );
            gone = True;
        } else {
            ddx = w.shots.items[i].x - w.player.x;
            ddy = w.shots.items[i].y - w.player.y;
            ddz = w.shots.items[i].z - w.player.z;
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
    while i < w.sparks.size() {
        if w.sparks.items[i].step() {
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
        w.player.vy = 0.0;
        w.player.grounded = True;
        w.cmd.jump = False;
        w.player.prev_z = SPAWN_Z;
    }
}

impl process_events(w: &mut Game) {
    swap(&mut w.events, &mut w.processing);
    bi = 0;
    while bi < len(w.processing.booms) {
        bx = w.processing.booms[bi].x;
        `by = w.processing.booms[bi].y;
        bz = w.processing.booms[bi].z;
        for ei in range(MAX_ENEMIES) {
            if w.enemies.items[ei].alive == 1 {
                ddx = w.enemies.items[ei].x - bx;
                ddy = w.enemies.items[ei].y - `by;
                ddz = w.enemies.items[ei].z - bz;
                if ddx * ddx + ddy * ddy + ddz * ddz < BLAST_R2 {
                    w.processing.kill(
                        ei,
                        w.enemies.items[ei].gen,
                        w.enemies.items[ei].x,
                        w.enemies.items[ei].y,
                        w.enemies.items[ei].z
                    );
                }
            }
        }
        spark_burst(w, bx, `by, bz, 10, 6.0, 255, 150, 60);
        spark_burst(w, bx, `by, bz, 6, 3.5, 255, 220, 120);
        spawn_spark(w, bx, `by, bz, 0.0, 0.6, 0.0, 0.28, 0.9, -0.5, 255, 235, 160);
        bi += 1;
    }
    w.processing.booms.clear();

    ki = 0;
    while ki < len(w.processing.kills) {
        slot = w.processing.kills[ki].slot;
        if w.enemies.items[slot].alive == 1
            and w.enemies.items[slot].gen == w.processing.kills[ki].gen {
            w.enemies.items[slot].alive = 0;
            w.enemies.items[slot].gen += 1;
            w.enemies.items[slot].respawn_t = rand_range(&mut w.rng, 1.2, 2.6);
            w.stats.score += 1;
            kx = w.processing.kills[ki].x;
            ky = w.processing.kills[ki].y;
            kz = w.processing.kills[ki].z;
            spark_burst(w, kx, ky, kz, 12, 7.0, 235, 90, 60);
            spark_burst(w, kx, ky, kz, 5, 4.0, 255, 210, 110);
        }
        ki += 1;
    }
    w.processing.kills.clear();

    di = 0;
    while di < len(w.processing.damage) {
        apply_damage(w, w.processing.damage[di]);
        di += 1;
    }
    w.processing.damage.clear();
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

impl world_new -> own Game {
    w = Game();
    for i in range(MAX_ENEMIES) {
        w.enemies.items.append(Enemy());
    }
    for i in range(MAX_ENEMIES) {
        respawn_enemy(&mut w, i);
    }
    return w;
}

impl Spark.step -> bool {
    self.x += self.vx * TICK_DT;
    self.y += self.vy * TICK_DT;
    self.z += self.vz * TICK_DT;
    self.vy -= self.grav * TICK_DT;
    if self.y < 0.05 and self.grav > 0.0 {
        self.y = 0.05;
        self.vy = -self.vy * 0.35;
        self.vx = self.vx * 0.7;
        self.vz = self.vz * 0.7;
    }
    self.life -= TICK_DT;
    return self.life <= 0.0;
}
