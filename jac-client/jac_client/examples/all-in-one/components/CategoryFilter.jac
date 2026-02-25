# Category filter component
# Demonstrates: iteration with map, conditional classes, events
cl import from ..constants.categories {
    CATEGORIES,
    CATEGORY_LABELS,
    CATEGORY_COLORS
}

cl {
    # Filter buttons for categories
    def:pub CategoryFilter(selectedCategory: str, onSelect: any) -> JsxElement {
        # Add "ALL" to the beginning of categories
        allCategories = ["ALL"].concat(CATEGORIES);

        return
            <div className="category-filter">
                <h3 className="filter-title">
                    Filter by Category
                </h3>
                <div className="filter-buttons">
                    {[
                        <button
                            key={cat}
                            className={("filter-btn active")
                            if selectedCategory == cat
                            else ("filter-btn")}
                            style={{
                                "borderColor": CATEGORY_COLORS[cat]
                                if cat != "ALL"
                                else "#374151",
                                "backgroundColor": (
                                    CATEGORY_COLORS[cat] if cat != "ALL" else "#374151"
                                )
                                if selectedCategory == cat
                                else ("transparent"),
                                "color": ("#fff")
                                if selectedCategory == cat
                                else (
                                    CATEGORY_COLORS[cat] if cat != "ALL" else "#374151"
                                )
                            }}
                            onClick={lambda : onSelect(cat)}
                        >
                            {(cat) if cat == "ALL" else (CATEGORY_LABELS[cat])}
                        </button> for cat in allCategories
                    ]}
                </div>
            </div>;
    }
}
