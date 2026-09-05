import from core.site.game.webgl_host { run_game }

impl WasmGame.launch(_e: MouseEvent) {
    launched = True;
    if canvasRef.current {
        stopRef.current = run_game(
            canvasRef.current,
            lambda (exports: any, game: any, fps: int) {
                score_el: any = document.getElementById("game-hud-score");
                hp_el: any = document.getElementById("game-hud-hp");
                deaths_el: any = document.getElementById("game-hud-deaths");
                fps_el: any = document.getElementById("game-hud-fps");
                if score_el {
                    score_el.textContent = exports.get_score(game);
                }
                if hp_el {
                    hp_el.textContent = Math.round(exports.get_hp(game));
                }
                if deaths_el {
                    deaths_el.textContent = exports.get_deaths(game);
                }
                if fps_el {
                    fps_el.textContent = fps;
                }
            },
        );
    }
}
