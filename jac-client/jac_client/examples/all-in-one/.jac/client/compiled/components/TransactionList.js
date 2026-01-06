import {__jacJsx, __jacSpawn} from "@jac-client/utils";
import { TransactionItem } from "./TransactionItem.js";
export function TransactionList(props) {
  const {transactions, onDelete} = props;
  if (transactions.length === 0) {
    return __jacJsx("div", {"className": "empty-state"}, [__jacJsx("p", {}, ["No transactions yet."]), __jacJsx("p", {}, ["Add your first income or expense above!"])]);
  }
  return __jacJsx("div", {"className": "transaction-list"}, [__jacJsx("h3", {"className": "list-title"}, ["Transactions (", transactions.length, ")"]), transactions.map(tx => {
    return __jacJsx(TransactionItem, {"key": tx["id"], "id": tx["id"], "description": tx["description"], "amount": tx["amount"], "category": tx["category"], "txType": tx["type"], "date": tx["date"], "isBusiness": tx["isBusinessTransaction"] || false, "clientName": tx["clientName"] || null, "onDelete": onDelete}, []);
  })]);
}