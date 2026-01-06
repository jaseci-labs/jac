import {__jacJsx, __jacSpawn} from "@jac-client/utils";
import { useBudgetContext } from "../context/BudgetContext.js";
import { formatCurrency } from "../utils/formatters.js";
export function ProfitOverview() {
  let budget = useBudgetContext();
  let businessIncome = budget["businessIncome"];
  let businessExpenses = budget["businessExpenses"];
  let taxReserve = budget["taxReserve"];
  let netProfit = budget["netProfit"];
  return __jacJsx("div", {"className": "profit-overview"}, [__jacJsx("h3", {"className": "profit-title"}, ["Monthly Profit Snapshot"]), __jacJsx("div", {"className": "profit-breakdown"}, [__jacJsx("div", {"className": "profit-row income"}, [__jacJsx("span", {"className": "profit-label"}, ["Business Income"]), __jacJsx("span", {"className": "profit-value positive"}, ["+", formatCurrency(businessIncome)])]), __jacJsx("div", {"className": "profit-row expense"}, [__jacJsx("span", {"className": "profit-label"}, ["Business Expenses"]), __jacJsx("span", {"className": "profit-value negative"}, ["-", formatCurrency(businessExpenses)])]), __jacJsx("div", {"className": "profit-row tax"}, [__jacJsx("span", {"className": "profit-label"}, ["Tax Reserve (20%)"]), __jacJsx("span", {"className": "profit-value negative"}, ["-", formatCurrency(taxReserve)])]), __jacJsx("div", {"className": "profit-row total"}, [__jacJsx("span", {"className": "profit-label"}, ["Net Profit"]), __jacJsx("span", {"className": netProfit >= 0 ? "profit-value bold positive" : "profit-value bold negative"}, [netProfit > 0 ? "+" : "", formatCurrency(netProfit)])])])]);
}