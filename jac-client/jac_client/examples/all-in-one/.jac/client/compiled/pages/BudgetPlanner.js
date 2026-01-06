import {__jacJsx, __jacSpawn} from "@jac-client/utils";
import { useState } from "react";
import { useBudgetContext } from "../context/BudgetContext.js";
import { Header } from "../components/Header.js";
import { Summary } from "../components/Summary.js";
import { ProfitOverview } from "../components/ProfitOverview.js";
import { TransactionForm } from "../components/TransactionForm.js";
import { TransactionList } from "../components/TransactionList.js";
import { CategoryFilter } from "../components/CategoryFilter.js";
import { CATEGORY_COLORS } from "../constants/categories.js";
import { PieChart } from "../components/PieChart.tsx";
export function BudgetPlanner() {
  let [filter, setFilter] = useState("ALL");
  let budget = useBudgetContext();
  let filtered = budget["transactions"];
  if (filter !== "ALL") {
    filtered = filtered.filter(tx => {
      return tx["category"] === filter;
    });
  }
  let sorted = filtered.slice().sort((a, b) => {
    return Reflect.construct(Date, [b["date"]]).getTime() - Reflect.construct(Date, [a["date"]]).getTime();
  });
  let chartData = budget["expensesByCategory"].map(item => {
    return {"name": item["name"], "value": item["value"], "color": CATEGORY_COLORS[item["name"]]};
  });
  return __jacJsx("div", {"className": "app-container"}, [__jacJsx(Header, {}, []), __jacJsx("main", {"className": "main-content"}, [__jacJsx("div", {"className": "left-panel"}, [__jacJsx(Summary, {}, []), __jacJsx(ProfitOverview, {}, []), __jacJsx(TransactionForm, {}, []), __jacJsx(CategoryFilter, {"selectedCategory": filter, "onSelect": setFilter}, []), __jacJsx(TransactionList, {"transactions": sorted, "onDelete": budget["deleteTransaction"]}, [])]), __jacJsx("div", {"className": "right-panel"}, [__jacJsx(PieChart, {"data": chartData, "title": "Expense Breakdown", "colors": CATEGORY_COLORS}, [])])])]);
}
