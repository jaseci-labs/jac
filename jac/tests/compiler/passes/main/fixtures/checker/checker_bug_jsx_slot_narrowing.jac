"""Fixture: `T | None` narrowing must propagate into JSX statement slot bodies.

A `{...}` slot in JSX child position whose body begins with a statement
keyword (`for`, `if`, `while`, ...) is lowered by `ViewLowerPass` into an
accumulator-backed body (`acc = []; for ... { acc.append(<jsx>) } return
<>{acc}</>;`). Those lowered statements live as the slot's `body` list and
are visited by every later pass - but `CFGBuildPass` previously had no
`exit_jsx_slot` handler, so the slot body's statements were never wired
into the enclosing function's CFG. A name reference inside the slot's
loop header (e.g. `recipe.ingredients` in `{for ing in recipe.ingredients
{ ... }}`) found the surrounding `InForStmt` via `_find_cfg_node_for`,
discovered an empty `bb_in`, and dead-ended - losing any narrowing
established by an enclosing `if recipe is None { return; }` guard.

After the fix, every attribute access below must type-check.
"""

obj Recipe {
    has title: str;
    has ingredients: list[str] = [];
}

# Slot for-loop iterator depends on a narrowed attribute access.
def use_for(recipe: Recipe | None) -> JsxElement {
    if recipe is None { return <div>loading</div>; }
    return
        <ul>
            {for ing in recipe.ingredients {
                <li key={ing}>{ing}</li>
            }}
        </ul>;
}

# Slot inside the positive branch of an enclosing `is not None` guard.
def use_positive_guard(recipe: Recipe | None) -> JsxElement {
    if recipe is not None {
        return
            <ul>
                {for ing in recipe.ingredients {
                    <li key={ing}>{ing}</li>
                }}
            </ul>;
    }
    return <div>missing</div>;
}

# Slot `if` whose condition references a narrowed value.
def use_if_cond(recipe: Recipe | None) -> JsxElement {
    if recipe is None { return <div>loading</div>; }
    return
        <section>
            {if len(recipe.ingredients) == 0 {
                <p>none</p>
                return;
            }}
            <h2>{recipe.title}</h2>
        </section>;
}

# Slot interpolation reads a narrowed attribute.
def use_interp(recipe: Recipe | None) -> JsxElement {
    if recipe is None { return <div>loading</div>; }
    return
        <ul>
            {for ing in ["a", "b"] {
                <li key={ing}>{recipe.title + ":" + ing}</li>
            }}
        </ul>;
}

# Slot nested inside another slot - narrowing must reach the inner one too.
def use_nested(recipe: Recipe | None) -> JsxElement {
    if recipe is None { return <div>loading</div>; }
    return
        <section>
            {if len(recipe.ingredients) > 0 {
                <ul>
                    {for ing in recipe.ingredients {
                        <li key={ing}>{ing}</li>
                    }}
                </ul>
            }}
        </section>;
}
