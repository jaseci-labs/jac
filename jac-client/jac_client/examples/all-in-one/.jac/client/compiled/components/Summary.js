import {__jacJsx, __jacSpawn} from "@jac-client/utils";
import { useBudgetContext } from "../context/BudgetContext.js";
import { formatCurrency } from "../utils/formatters.js";
export function Summary() {
  let budget = useBudgetContext();
  let businessIncome = budget["businessIncome"];
  let businessExpenses = budget["businessExpenses"];
  let personalIncome = budget["personalIncome"];
  let personalExpenses = budget["personalExpenses"];
  let taxReserve = budget["taxReserve"];
  let netProfit = budget["netProfit"];
  return __jacJsx("div", {"className": "summary"}, [__jacJsx("div", {"className": "summary-card business-income"}, [__jacJsx("span", {"className": "summary-label"}, ["Business Income"]), __jacJsx("span", {"className": "summary-value"}, [formatCurrency(businessIncome)])]), __jacJsx("div", {"className": "summary-card business-expenses"}, [__jacJsx("span", {"className": "summary-label"}, ["Business Expenses"]), __jacJsx("span", {"className": "summary-value"}, [formatCurrency(businessExpenses)])]), __jacJsx("div", {"className": "summary-card personal-income"}, [__jacJsx("span", {"className": "summary-label"}, ["Personal Income"]), __jacJsx("span", {"className": "summary-value"}, [formatCurrency(personalIncome)])]), __jacJsx("div", {"className": "summary-card personal-expenses"}, [__jacJsx("span", {"className": "summary-label"}, ["Personal Expenses"]), __jacJsx("span", {"className": "summary-value"}, [formatCurrency(personalExpenses)])]), __jacJsx("div", {"className": "summary-card tax-reserve"}, [__jacJsx("span", {"className": "summary-label"}, ["Tax Reserve (20%)"]), __jacJsx("span", {"className": "summary-value"}, [formatCurrency(taxReserve)])]), __jacJsx("div", {"className": netProfit >= 0 ? "summary-card net-profit positive" : "summary-card net-profit negative"}, [__jacJsx("span", {"className": "summary-label"}, ["Net Profit"]), __jacJsx("span", {"className": "summary-value"}, [netProfit > 0 ? "+" : "", formatCurrency(netProfit)])])]);
}
