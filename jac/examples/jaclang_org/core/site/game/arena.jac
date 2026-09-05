import from platform_rl {
    open_window,
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

glob acc: float = 0.0,
     prev_mx: float = 0.0,
     prev_my: float = 0.0,
     mouse_warmup: int = 12,
     mouse_sens: float = 0.12,
     mouse_captured: bool = False;

def sample_input(w: &mut Game, dtf: float);

def draw_enemy_model(ex: float, ey: float, ez: float, k: float);

def draw_enemies(w: &Game, alpha: float);

def draw_rockets(w: &Game, alpha: float);

def draw_shots(w: &Game, alpha: float, rt: float);

def draw_sparks(w: &Game, alpha: float);

def draw_weapon(w: &Game, cx: float, cy: float, cz: float, rt: float);

def draw_hud(w: &Game, rt: float);

def render(w: &Game, alpha: float);

def init -> Game;

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
