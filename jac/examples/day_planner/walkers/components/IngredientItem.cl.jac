"""Single ingredient row -- presentational."""

sv import from ..main { ShoppingItem }

def:pub IngredientItem(ing: ShoppingItem) -> JsxElement {
    return
        <div class="ingredient-item">
            <div class="ing-info">
                <span class="ing-name">{ing.name}</span>
                <span class="ing-qty">{ing.quantity} {ing.unit}</span>
            </div>
            <div class="ing-meta">
                {(<span class="carb-badge">Carbs</span>) if ing.carby else None}
                <span class="ing-cost">${f"{ing.cost:.2f}"}</span>
            </div>
        </div>;
}
