def model_apply(ctx: EffectContext, fiber: Fiber);


def tools_apply(ctx: EffectContext, fiber: Fiber);


def render_apply(ctx: EffectContext, fiber: Fiber);


def render_v2_apply(ctx: EffectContext, fiber: Fiber);


test "set is tracked and recoverable at root" {
    ctx = EffectContext();
    ctx.set("model", "m1");
    assert ctx.has_key("model");
    while ctx.root_frame {
        inv = ctx.root_frame.pop();
        inv.run();
    }
    assert not ctx.has_key("model");
}


test "dependent waits until provider arrives, then activates" {
    ctx = EffectContext();
    tools = Fiber(
        name="tools",
        inject=["model"],
        provide=["tools.read", "tools.edit"],
        apply=tools_apply
    );
    ctx.use(tools);
    assert not tools.active;
    model = Fiber(name="model", provide=["model", "model.health"], apply=model_apply);
    ctx.use(model);
    assert model.active;
    assert tools.active;
    assert ctx.get("tools.read") == "read_file(claude-sonnet-5)";
}


test "unloading provider deactivates dependents and reverts their effects" {
    ctx = EffectContext();
    ctx.use(
        Fiber(
            name="tools",
            inject=["model"],
            provide=["tools.read", "tools.edit"],
            apply=tools_apply
        )
    );
    ctx.use(Fiber(name="model", provide=["model", "model.health"], apply=model_apply));
    assert ctx.get("tools.read") is not None;

    ctx.unload("model");
    assert not ctx.registry["tools"].active;
    assert not ctx.has_key("tools.read");
    assert not ctx.has_key("tools.edit");
    assert not ctx.has_key("model");
}


test "re-providing reactivates waiting dependents" {
    ctx = EffectContext();
    tools = Fiber(
        name="tools",
        inject=["model"],
        provide=["tools.read", "tools.edit"],
        apply=tools_apply
    );
    ctx.use(tools);
    model = Fiber(name="model", provide=["model", "model.health"], apply=model_apply);
    ctx.use(model);
    ctx.unload("model");
    assert not tools.active;

    ctx.use(Fiber(name="model2", provide=["model", "model.health"], apply=model_apply));
    assert tools.active;
    assert ctx.get("tools.read") is not None;
}


test "hot swap recovers old component effects and installs new ones" {
    ctx = EffectContext();
    ctx.use(
        Fiber(
            name="renderer", provide=["renderer", "slash./render"], apply=render_apply
        )
    );
    assert ctx.get("slash./render") == "render_v1";

    ctx.swap(
        "renderer",
        Fiber(
            name="renderer",
            provide=["renderer", "slash./render"],
            apply=render_v2_apply
        )
    );
    assert ctx.get("renderer") == "ansi";
    assert ctx.get("slash./render") == "render_v2";
    assert len(
        [
            k
            for k in ctx.store
            if k.startswith("slash.")
        ]
    )
        == 1;
}


test "dispose_all leaves the context empty" {
    ctx = EffectContext();
    ctx.use(Fiber(name="model", provide=["model", "model.health"], apply=model_apply));
    ctx.use(
        Fiber(
            name="tools",
            inject=["model"],
            provide=["tools.read", "tools.edit"],
            apply=tools_apply
        )
    );
    ctx.dispose_all();
    assert len(ctx.store) == 0;
    assert len(ctx.registry) == 0;
}

impl model_apply(ctx: EffectContext, fiber: Fiber) {
    ctx.set("model", "claude-sonnet-5");
    ctx.set("model.health", "ok");
}


impl tools_apply(ctx: EffectContext, fiber: Fiber) {
    m = ctx.get("model");
    ctx.set("tools.read", "read_file(" + str(m) + ")");
    ctx.set("tools.edit", "edit_file");
}


impl render_apply(ctx: EffectContext, fiber: Fiber) {
    ctx.set("renderer", "plain");
    ctx.set("slash./render", "render_v1");
}


impl render_v2_apply(ctx: EffectContext, fiber: Fiber) {
    ctx.set("renderer", "ansi");
    ctx.set("slash./render", "render_v2");
}
