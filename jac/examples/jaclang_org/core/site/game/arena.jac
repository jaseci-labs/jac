import from platform_rl {
    open_window,
    close_window,
    should_close,
    frame_dt,
    key_held,
    key_tapped,
    mouse_x,
    mouse_y,
    mouse_pressed,
    lock_mouse,
    unlock_mouse,
    begin_frame,
    end_frame,
    set_camera,
    begin_overlay,
    begin_model,
    end_model,
    draw_fps,
    draw_box,
    draw_floor,
    draw_rect2d,
    KEY_W,
    KEY_A,
    KEY_S,
    KEY_D,
    KEY_SPACE,
    KEY_RIGHT,
    KEY_LEFT,
    KEY_DOWN,
    KEY_UP,
    KEY_TAB,
    MOUSE_LEFT,
    SCREEN_W,
    SCREEN_H
}
import from sim {
    Game,
    Cmd,
    Player,
    Stats,
    EnemyPool,
    ProjectilePool,
    SparkPool,
    world_new,
    sim_tick,
    TICK_DT,
    TICK_MAX_CATCHUP,
    HP_MAX,
    CHARGE_T,
    FIRE_COOLDOWN,
    PITCH_LIMIT,
    MAX_ENEMIES
}
import from gmath { jsin, lerp, clampf }

obj RenderView {
    has cmd: &Cmd,
        player: &Player,
        stats: &Stats,
        enemies: &EnemyPool,
        rockets: &ProjectilePool,
        shots: &ProjectilePool,
        sparks: &SparkPool,
        time: float;
}

def sample_input(w: &mut Game, dtf: float);

def draw_enemy_model(ex: float, ey: float, ez: float, k: float);

def draw_enemies(w: &RenderView, alpha: float);

def draw_rockets(w: &RenderView, alpha: float);

def draw_shots(w: &RenderView, alpha: float, rt: float);

def draw_sparks(w: &RenderView, alpha: float);

def draw_weapon(w: &RenderView, cx: float, cy: float, cz: float, rt: float);

def draw_hud(w: &RenderView, rt: float);

def render(w: &RenderView, alpha: float);

def init -> own Game;

def shutdown(w: own Game) {
    close_window();
}

def frame(w: &mut Game) -> bool;

def get_score(w: &Game) -> int {
    return w.stats.score;
}

def get_hp(w: &Game) -> float {
    return w.player.hp;
}

def get_deaths(w: &Game) -> int {
    return w.stats.deaths;
}
