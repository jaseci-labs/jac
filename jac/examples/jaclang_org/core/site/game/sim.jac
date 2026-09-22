import from gmath { Rng, jcos, jsin, jsqrt, rand01, rand_range, rand_sign, DEG2RAD }

glob TICK_DT: float = 0.016666666666666666,
     TICK_MAX_CATCHUP: float = 0.1,
     MAX_ENEMIES: int = 8,
     MAX_ROCKETS: int = 10,
     MAX_SHOTS: int = 24,
     MAX_SPARKS: int = 90,
     MAX_EVENTS: int = 32;

glob HP_MAX: float = 100.0,
     HP_REGEN_RATE: float = 7.0,
     HP_REGEN_DELAY: float = 4.0,
     SHOT_DAMAGE: float = 9.0,
     DEATH_INVULN_T: float = 2.5,
     HURT_FLASH_T: float = 0.45,
     SPAWN_X: float = 0.0,
     SPAWN_Y: float = 2.0,
     SPAWN_Z: float = 12.0;

glob JUMP_SPEED: float = 8.0,
     GRAVITY: float = 22.0;

glob MOVE_SPEED: float = 8.0,
     PITCH_LIMIT: float = 85.0,
     FIRE_COOLDOWN: float = 0.55,
     ROCKET_SPEED: float = 30.0,
     ROCKET_LIFE: float = 3.0,
     ROCKET_HIT_R2: float = 2.1,
     BLAST_R2: float = 7.3;

glob CHARGE_T: float = 0.95,
     SHOT_SPEED: float = 12.0,
     SHOT_LIFE: float = 4.0,
     SHOT_HIT_R2: float = 1.2,
     ENEMY_STRAFE_SPEED: float = 3.0,
     ENEMY_ADVANCE_SPEED: float = 2.8,
     ENEMY_RETREAT_SPEED: float = 3.4,
     ENEMY_FAR_DIST: float = 17.0,
     ENEMY_NEAR_DIST: float = 8.0,
     ENEMY_SIGHT_DIST: float = 28.0,
     ARENA_HALF_X: float = 16.0,
     ARENA_Z_NEAR: float = 8.0,
     ARENA_Z_FAR: float = -18.0;

obj Cmd {
    has move_fwd: float = 0.0,
        move_side: float = 0.0,
        yaw: float = 0.0,
        pitch: float = 0.0,
        fire: bool = False,
        jump: bool = False;
}

obj Player {
    def tick(cmd: &mut Cmd) -> bool;

    has x: float = 0.0,
        y: float = 2.0,
        z: float = 12.0,
        prev_x: float = 0.0,
        prev_y: float = 2.0,
        prev_z: float = 12.0,
        yaw: float = 0.0,
        pitch: float = 0.0,
        vy: float = 0.0,
        grounded: bool = True,
        hp: float = 100.0,
        fire_cd: float = 0.0,
        hurt_t: float = 0.0,
        safe_t: float = 10.0,
        invuln_t: float = 0.0,
        kick_t: float = 0.0,
        muzzle_t: float = 0.0;
}

obj Stats {
    has score: int = 0,
        deaths: int = 0;
}

obj Enemy {
    has x: float = 0.0,
        y: float = 0.0,
        z: float = 0.0,
        prev_x: float = 0.0,
        prev_y: float = 0.0,
        prev_z: float = 0.0,
        base_y: float = 0.0,
        phase: float = 0.0,
        strafe_dir: float = 0.0,
        strafe_t: float = 0.0,
        fire_t: float = 0.0,
        charge: float = 0.0,
        respawn_t: float = 0.0,
        alive: int = 0,
        gen: int = 0;
}

obj Projectile {
    def step {
        self.x += self.vx * TICK_DT;
        self.y += self.vy * TICK_DT;
        self.z += self.vz * TICK_DT;
        self.life -= TICK_DT;
    }

    has x: float = 0.0,
        y: float = 0.0,
        z: float = 0.0,
        prev_x: float = 0.0,
        prev_y: float = 0.0,
        prev_z: float = 0.0,
        vx: float = 0.0,
        vy: float = 0.0,
        vz: float = 0.0,
        life: float = 0.0;
}

obj Spark {
    def step -> bool;

    has x: float = 0.0,
        y: float = 0.0,
        z: float = 0.0,
        prev_x: float = 0.0,
        prev_y: float = 0.0,
        prev_z: float = 0.0,
        vx: float = 0.0,
        vy: float = 0.0,
        vz: float = 0.0,
        life: float = 0.0,
        fade: float = 0.0,
        size: float = 0.0,
        grav: float = 0.0,
        cr: int = 0,
        cg: int = 0,
        cb: int = 0;
}

def remove_at[T](items: &mut list[own T], i: int) {
    last = items.pop();
    if i < len(items) {
        items[i] = last;
    }
}

obj EnemyPool {
    has items: list[own Enemy] = [];

    def size -> int {
        return len(self.items);
    }
}

obj ProjectilePool {
    has items: list[own Projectile] = [];

    def size -> int {
        return len(self.items);
    }

    def remove(i: int) {
        remove_at(&mut self.items, i);
    }
}

obj SparkPool {
    has items: list[own Spark] = [];

    def size -> int {
        return len(self.items);
    }

    def remove(i: int) {
        remove_at(&mut self.items, i);
    }
}

obj Boom {
    has x: float = 0.0,
        y: float = 0.0,
        z: float = 0.0;
}

obj Kill {
    has slot: int = 0,
        gen: int = 0,
        x: float = 0.0,
        y: float = 0.0,
        z: float = 0.0;
}

obj Events {
    has booms: list[own Boom] = [],
        kills: list[own Kill] = [],
        damage: list[float] = [];

    def boom(x: float, y: float, z: float) {
        if len(self.booms) < MAX_EVENTS {
            self.booms.append(Boom(x=x, y=y, z=z));
        }
    }

    def kill(slot: int, gen: int, x: float, y: float, z: float) {
        if len(self.kills) < MAX_EVENTS {
            self.kills.append(Kill(slot=slot, gen=gen, x=x, y=y, z=z));
        }
    }

    def hurt(amount: float) {
        if len(self.damage) < MAX_EVENTS {
            self.damage.append(amount);
        }
    }
}

obj FrameState {
    has acc: float = 0.0,
        prev_mx: float = 0.0,
        prev_my: float = 0.0,
        mouse_warmup: int = 12,
        mouse_sens: float = 0.12,
        mouse_captured: bool = False;
}

obj Game {
    has player: own Player = Player(),
        stats: own Stats = Stats(),
        cmd: own Cmd = Cmd(),
        enemies: own EnemyPool = EnemyPool(),
        rockets: own ProjectilePool = ProjectilePool(),
        shots: own ProjectilePool = ProjectilePool(),
        sparks: own SparkPool = SparkPool(),
        events: own Events = Events(),
        processing: own Events = Events(),
        input: own FrameState = FrameState(),
        rng: own Rng = Rng(),
        time: float = 0.0;
}

def push_boom(w: &mut Game, x: float, y: float, z: float);

def push_kill(w: &mut Game, slot: int, gen: int, x: float, y: float, z: float);

def push_damage(w: &mut Game, amount: float);

def spawn_spark(
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
);

def spark_burst(
    w: &mut Game,
    x: float,
    y: float,
    z: float,
    n: int,
    speed: float,
    cr: int,
    cg: int,
    cb: int
);

def remove_spark(w: &mut Game, i: int);

def remove_rocket(w: &mut Game, i: int);

def remove_shot(w: &mut Game, i: int);

def respawn_enemy(w: &mut Game, i: int);

def spawn_rocket(w: &mut Game);

def spawn_shot(w: &mut Game, ex: float, ey: float, ez: float);

def store_prev(w: &mut Game);

def tick_player(w: &mut Game);

def tick_enemies(w: &mut Game);

def tick_rockets(w: &mut Game);

def tick_shots(w: &mut Game);

def tick_sparks(w: &mut Game);

def apply_damage(w: &mut Game, amount: float);

def process_events(w: &mut Game);

def sim_tick(w: &mut Game);

def world_new -> own Game;
