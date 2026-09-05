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
        fire: bool = False;
}

obj Player {
    has x: float = 0.0,
        y: float = 2.0,
        z: float = 12.0,
        prev_x: float = 0.0,
        prev_y: float = 2.0,
        prev_z: float = 12.0,
        yaw: float = 0.0,
        pitch: float = 0.0,
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

obj EnemyPool {
    has x: list[float] = [],
        y: list[float] = [],
        z: list[float] = [],
        prev_x: list[float] = [],
        prev_y: list[float] = [],
        prev_z: list[float] = [],
        base_y: list[float] = [],
        phase: list[float] = [],
        strafe_dir: list[float] = [],
        strafe_t: list[float] = [],
        fire_t: list[float] = [],
        charge: list[float] = [],
        respawn_t: list[float] = [],
        alive: list[int] = [],
        gen: list[int] = [];
}

obj RocketPool {
    has x: list[float] = [],
        y: list[float] = [],
        z: list[float] = [],
        prev_x: list[float] = [],
        prev_y: list[float] = [],
        prev_z: list[float] = [],
        vx: list[float] = [],
        vy: list[float] = [],
        vz: list[float] = [],
        life: list[float] = [],
        count: int = 0;
}

obj ShotPool {
    has x: list[float] = [],
        y: list[float] = [],
        z: list[float] = [],
        prev_x: list[float] = [],
        prev_y: list[float] = [],
        prev_z: list[float] = [],
        vx: list[float] = [],
        vy: list[float] = [],
        vz: list[float] = [],
        life: list[float] = [],
        count: int = 0;
}

obj SparkPool {
    has x: list[float] = [],
        y: list[float] = [],
        z: list[float] = [],
        prev_x: list[float] = [],
        prev_y: list[float] = [],
        prev_z: list[float] = [],
        vx: list[float] = [],
        vy: list[float] = [],
        vz: list[float] = [],
        life: list[float] = [],
        fade: list[float] = [],
        size: list[float] = [],
        grav: list[float] = [],
        cr: list[int] = [],
        cg: list[int] = [],
        cb: list[int] = [],
        count: int = 0;
}

obj Events {
    has boom_x: list[float] = [],
        boom_y: list[float] = [],
        boom_z: list[float] = [],
        boom_n: int = 0,
        kill_slot: list[int] = [],
        kill_gen: list[int] = [],
        kill_x: list[float] = [],
        kill_y: list[float] = [],
        kill_z: list[float] = [],
        kill_n: int = 0,
        dmg: list[float] = [],
        dmg_n: int = 0;
}

obj Game {
    has player: Player = Player(),
        stats: Stats = Stats(),
        cmd: Cmd = Cmd(),
        enemies: EnemyPool = EnemyPool(),
        rockets: RocketPool = RocketPool(),
        shots: ShotPool = ShotPool(),
        sparks: SparkPool = SparkPool(),
        events: Events = Events(),
        rng: Rng = Rng(),
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

def world_new -> Game;
