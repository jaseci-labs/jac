import from core.site.game.webgl_host { run_game }

impl WasmGame.launch(_e: MouseEvent) {
    launched = True;
    if canvasRef.current {
        stopRef.current = run_game(
            canvasRef.current,
            lambda (score: int, hp: float, deaths: int, fps: int) {
                score_el = scoreRef.current;
                hp_el = hpRef.current;
                deaths_el = deathsRef.current;
                fps_el = fpsRef.current;
                if score_el {
                    score_el.textContent = str(score);
                }
                if hp_el {
                    hp_el.textContent = str(Math.round(hp));
                }
                if deaths_el {
                    deaths_el.textContent = str(deaths);
                }
                if fps_el {
                    fps_el.textContent = str(fps);
                }
            },
        );
    }
}
