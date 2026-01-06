import {__jacJsx, __jacSpawn} from "@jac-client/utils";
import { formatCurrency, formatDate } from "../utils/formatters.js";
import { CATEGORY_COLORS, CATEGORY_LABELS } from "../constants/categories.js";
export function TransactionItem(props) {
  const {id, description, amount, category, txType, date, isBusiness, clientName, onDelete} = props;
  let isIncome = txType === "income";
  let color = CATEGORY_COLORS[category];
  let label = CATEGORY_LABELS[category];
  return __jacJsx("div", {"className": "transaction-item"}, [__jacJsx("div", {"className": "tx-left"}, [__jacJsx("span", {"className": "tx-category", "style": {"backgroundColor": color}}, [label]), __jacJsx("div", {"className": "tx-details"}, [__jacJsx("span", {"className": "tx-description"}, [description, clientName !== null && isIncome && __jacJsx("span", {"className": "tx-client"}, [" • ", clientName])]), __jacJsx("span", {"className": "tx-date"}, [formatDate(date)])])]), __jacJsx("div", {"className": "tx-right"}, [__jacJsx("span", {"className": isIncome ? "tx-amount income" : "tx-amount expense"}, [isIncome ? "+" : "-", formatCurrency(amount)]), __jacJsx("button", {"className": "delete-btn", "onClick": () => onDelete(id), "title": "Delete transaction"}, ["X"])])]);
}
