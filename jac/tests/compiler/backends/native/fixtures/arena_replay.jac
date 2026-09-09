import from sim { Game, world_new, sim_tick }

def replay {
    w = world_new();
    for i in range(1800) {
        w.cmd.fire = i % 35 == 0;
        w.cmd.yaw = float(i % 360);
        w.cmd.move_fwd = 0.25;
        sim_tick(&mut w);
        if i % 300 == 299 {
            print(
                w.stats.score, w.stats.deaths, int(w.player.hp * 1000.0), w.rng.state
            );
        }
    }
}

with entry {
    replay();
}
