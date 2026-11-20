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

def:pub init -> own Game;

def:pub shutdown(w: own Game);

def:pub frame(w: &mut Game) -> bool;

def:pub get_score(w: &Game) -> int;

def:pub get_hp(w: &Game) -> float;

def:pub get_deaths(w: &Game) -> int;
