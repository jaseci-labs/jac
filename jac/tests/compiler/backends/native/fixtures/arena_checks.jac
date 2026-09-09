import from sim {
    Game,
    Projectile,
    Spark,
    world_new,
    tick_player,
    apply_damage,
    spawn_rocket,
    push_kill,
    process_events,
    MAX_ROCKETS,
    SPAWN_Y
}

def jump_checks {
    w = world_new();
    w.cmd.jump = True;
    tick_player(&mut w);
    assert w.player.y > SPAWN_Y;
    assert not w.player.grounded;
    assert not w.cmd.jump;
    assert w.rockets.size() == 0;
    velocity = w.player.vy;
    w.cmd.jump = True;
    tick_player(&mut w);
    assert w.player.vy < velocity;
    for i in range(120) {
        tick_player(&mut w);
    }
    assert w.player.y == SPAWN_Y;
    assert w.player.vy == 0.0;
    assert w.player.grounded;
    w.cmd.jump = True;
    w.cmd.fire = True;
    tick_player(&mut w);
    assert w.player.y > SPAWN_Y;
    assert w.rockets.size() == 1;
    assert not w.cmd.fire;
    w.player.invuln_t = 0.0;
    apply_damage(&mut w, 1000.0);
    assert w.stats.deaths == 1;
    assert w.player.y == SPAWN_Y and w.player.prev_y == SPAWN_Y;
    assert w.player.grounded and w.player.vy == 0.0;
}

def pool_checks {
    w = world_new();
    for i in range(MAX_ROCKETS + 5) {
        spawn_rocket(&mut w);
    }
    assert w.rockets.size() == MAX_ROCKETS;
    w.rockets.items[MAX_ROCKETS - 1].x = 42.0;
    w.rockets.items[MAX_ROCKETS - 1].prev_x = 41.0;
    w.rockets.remove(0);
    assert w.rockets.size() == MAX_ROCKETS - 1;
    assert w.rockets.items[0].x == 42.0;
    assert w.rockets.items[0].prev_x == 41.0;
    while w.rockets.size() > 0 {
        w.rockets.remove(w.rockets.size() - 1);
    }
    assert w.rockets.size() == 0;
    w.sparks.items.append(Spark(x=1.0, cr=12));
    w.sparks.items.append(Spark(x=2.0, cr=34));
    w.sparks.remove(0);
    assert w.sparks.items[0].x == 2.0 and w.sparks.items[0].cr == 34;
}

def event_checks {
    w = world_new();
    generation = w.enemies.items[0].gen;
    push_kill(&mut w, 0, generation, 0.0, 2.0, 0.0);
    push_kill(&mut w, 0, generation, 0.0, 2.0, 0.0);
    process_events(&mut w);
    assert w.stats.score == 1;
    assert w.enemies.items[0].gen == generation + 1;
    assert len(w.events.kills) == 0 and len(w.processing.kills) == 0;
    process_events(&mut w);
    assert w.stats.score == 1;
    w.enemies.items[0].alive = 1;
    push_kill(&mut w, 0, generation, 0.0, 2.0, 0.0);
    process_events(&mut w);
    assert w.stats.score == 1 and w.enemies.items[0].alive == 1;
}

with entry {
    jump_checks();
    pool_checks();
    event_checks();
    print("arena checks passed");
}
