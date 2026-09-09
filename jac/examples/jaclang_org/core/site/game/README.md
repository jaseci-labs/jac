# Rocket Arena

WASD moves, mouse/arrows aim, **Space jumps**, and **left click shoots**.
Click the canvas to capture the pointer; Tab/Esc releases it. Key presses are
queued until the next simulation tick, and holding Space does not repeat a jump.

`sim.jac` owns the simulation. Scalar `Enemy`, `Projectile`, and `Spark` records
replace parallel field arrays. Projectile and spark pools are bounded and remove
expired entries by moving the last record into the vacant slot. Enemy slots stay
stable; kill events carry generation numbers so duplicate or stale hits cannot
score twice. The fixed timestep, seeded random stream, and previous positions for
interpolation are independent of rendering.

`Game` owns its state, pools, two event buffers, random generator, and frame/input
state. `Player.tick` and entity methods infer mutating receivers. Event processing
swaps the pending and processing buffers, preserving the explosion/kill/damage
ordering within a tick. `RenderView` borrows only the state rendering needs and
cannot outlive the game.

`arena.jac` adapts input and rendering through `platform_rl.jac`. Its `init` returns
an owned game; `shutdown` consumes it and closes the window. Frame rendering uses
`finally` to balance frame completion. The browser host keeps the Wasm handle at
one explicit boundary; stopping takes that handle before calling shutdown,
cancels animation, removes listeners, and deletes GL resources. Session numbers
prevent stale asynchronous starts, frame callbacks, or stop callbacks from
changing a replacement game. HUD consumers receive scalar values, not Wasm
exports or pointers. Dynamic types are confined to the WebGL/Wasm interfaces.

Run simulation regression tests from the repository root:

```sh
jac test jac/tests/compiler/backends/native/test_arena_simulation.jac
jac test jac/tests/compiler/backends/es/test_arena_host.jac
```

The tests compile the same game source under managed, RC, and nogc memory profiles
and execute it through `jac run --backend python`. They cover jumping and landing,
death reset, pool limits and removal, duplicate/stale events, and a seeded replay
captured from the original simulation. The site's memory profile remains managed;
headerless suitability is validated independently rather than changing memory
policy for the rest of the website.

The host test compiles the actual browser adapter and exercises it with a
controlled Wasm boundary and browser API doubles. It checks scalar HUD values,
keyboard repeat, mouse buttons, pending initialization, stale stop callbacks,
and balanced resource cleanup. It uses the existing bundled JavaScript runtime.
