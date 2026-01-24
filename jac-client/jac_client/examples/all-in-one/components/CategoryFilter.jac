# Category filter component
# Demonstrates: iteration with map, conditional classes, events
cl import from ..constants.categories {
    CATEGORIES,
    CATEGORY_LABELS,
    CATEGORY_COLORS
}

cl {
    # Filter buttons for categories
    def:pub CategoryFilter(selectedCategory: str, onSelect: any) -> any {
        # Add "ALL" to the beginning of categories
        allCategories = ["ALL"].concat(CATEGORIES);

        return
            <div className="category-filter">
                <h3 className="filter-title">
                    Filter by Category
                </h3>
                <div className="filter-buttons">
                    {allCategories.map(
                        lambda cat: str  -> any { isActive = selectedCategory == cat;color = CATEGORY_COLORS[
                            cat
                        ]
                        if cat != "ALL"
                        else "#374151";return
                            <button
                                key={cat}
                                className={("filter-btn active")
                                if isActive
                                else ("filter-btn")}
                                style={{
                                    "borderColor": color,
                                    "backgroundColor": (color)
                                    if isActive
                                    else ("transparent"),
                                    "color": ("#fff") if isActive else (color)
                                }}
                                onClick={lambda : onSelect(cat)}
                            >
                                {(cat) if cat == "ALL" else (CATEGORY_LABELS[cat])}
                            </button>; }
                    )}
                </div>
            </div>;
    }
}
