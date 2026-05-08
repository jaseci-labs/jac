"""Shopping list column -- owns ingredient state, spawns walkers."""

sv import from ..main {
    ShoppingItem,
    GenerateShoppingList,
    GetShoppingList,
    ClearShoppingList
}

import from .IngredientItem { IngredientItem }

def:pub ShoppingPanel -> JsxElement {
    has ingredients: list[ShoppingItem] = [],
        mealText: str = "",
        generating: bool = False;

    async can with entry {
        result = root spawn GetShoppingList();
        ingredients = result.reports[0] if result.reports else [];
    }

    async def generateList {
        if not mealText.strip() {
            return;
        }
        generating = True;
        result = root spawn GenerateShoppingList(meal_description=mealText);
        ingredients = result.reports[0] if result.reports else [];
        generating = False;
    }

    async def clearList {
        root spawn ClearShoppingList();
        ingredients = [];
        mealText = "";
    }

    def handleKeyPress(e: KeyboardEvent) {
        if e.key == "Enter" {
            generateList();
        }
    }

    totalCost = 0.0;
    for ing in ingredients {
        totalCost = totalCost + ing.cost;
    }

    return
        <div class="column">
            <h2>Meal Shopping List</h2>
            <div class="input-row">
                <input
                    class="input"
                    value={mealText}
                    onChange={lambda e: ChangeEvent { mealText = e.target.value; }}
                    onKeyPress={handleKeyPress}
                    placeholder="e.g. 'chicken stir fry for 4'"
                />
                <button
                    class="btn-generate"
                    onClick={lambda { generateList(); }}
                    disabled={generating}
                >
                    {("Generating..." if generating else "Generate")}
                </button>
            </div>
            {(<div class="generating-msg">Generating with AI...</div>)
                if generating
                else (
                    <div>
                        {(
                            <div class="empty-msg">
                                Enter a meal above to generate ingredients.
                            </div>
                        )
                            if len(ingredients) == 0
                            else (
                                <div>
                                    {[
                                        <IngredientItem key={ing.name} ing={ing}/>
                                        for ing in ingredients
                                    ]}
                                    <div class="shopping-footer">
                                        <span class="total">
                                            Total: ${f"{totalCost:.2f}"}
                                        </span>
                                        <button
                                            class="btn-clear"
                                            onClick={lambda { clearList(); }}
                                        >
                                            Clear
                                        </button>
                                    </div>
                                </div>
                            )}
                    </div>
                )}
        </div>;
}
