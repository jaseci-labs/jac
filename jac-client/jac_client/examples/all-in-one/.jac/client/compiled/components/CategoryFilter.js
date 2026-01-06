import {__jacJsx, __jacSpawn} from "@jac-client/utils";
import { CATEGORIES, CATEGORY_LABELS, CATEGORY_COLORS } from "../constants/categories.js";
export function CategoryFilter(props) {
  const {selectedCategory, onSelect} = props;
  let allCategories = ["ALL"].concat(CATEGORIES);
  return __jacJsx("div", {"className": "category-filter"}, [__jacJsx("h3", {"className": "filter-title"}, ["Filter by Category"]), __jacJsx("div", {"className": "filter-buttons"}, [allCategories.map(cat => {
    let isActive = selectedCategory === cat;
    let color = cat !== "ALL" ? CATEGORY_COLORS[cat] : "#374151";
    return __jacJsx("button", {"key": cat, "className": isActive ? "filter-btn active" : "filter-btn", "style": {"borderColor": color, "backgroundColor": isActive ? color : "transparent", "color": isActive ? "#fff" : color}, "onClick": () => onSelect(cat)}, [cat === "ALL" ? cat : CATEGORY_LABELS[cat]]);
  })])]);
}