import {__jacJsx, __jacSpawn} from "@jac-client/utils";
import { useState, useCallback, useMemo } from "react";
export function useBudget() {
  let [transactions, setTransactions] = useState([]);
  function addTransaction(description, amount, category, txType, isBusiness, clientName) {
    let newTx = {"id": Date.now().toString(), "description": description, "amount": amount, "category": category, "type": txType, "date": Reflect.construct(Date, []).toISOString(), "isBusinessTransaction": isBusiness, "clientName": clientName !== "" ? clientName : null};
    setTransactions(transactions.concat([newTx]));
  }
  function deleteTransaction(id) {
    let filtered = transactions.filter(tx => {
      return tx["id"] !== id;
    });
    setTransactions(filtered);
  }
  let totalIncome = 0.0;
  let totalExpenses = 0.0;
  for (const tx of transactions) {
    if (tx["type"] === "income") {
      totalIncome = totalIncome + tx["amount"];
    } else {
      totalExpenses = totalExpenses + tx["amount"];
    }
  }
  let balance = totalIncome - totalExpenses;
  let businessIncome = 0.0;
  let businessExpenses = 0.0;
  let personalIncome = 0.0;
  let personalExpenses = 0.0;
  for (const tx of transactions) {
    let isBusiness = tx["isBusinessTransaction"] || false;
    let amount = tx["amount"];
    if (tx["type"] === "income") {
      if (isBusiness) {
        businessIncome = businessIncome + amount;
      } else {
        personalIncome = personalIncome + amount;
      }
    } else {
      if (isBusiness) {
        businessExpenses = businessExpenses + amount;
      } else {
        personalExpenses = personalExpenses + amount;
      }
    }
  }
  let TAX_RATE = 0.20;
  let taxReserve = businessIncome * TAX_RATE;
  let netProfit = businessIncome - businessExpenses - taxReserve;
  function getExpensesByCategory() {
    let categoryTotals = {};
    for (const tx of transactions) {
      if (tx["type"] === "expense") {
        let cat = tx["category"];
        if (categoryTotals[cat]) {
          categoryTotals[cat] = categoryTotals[cat] + tx["amount"];
        } else {
          categoryTotals[cat] = tx["amount"];
        }
      }
    }
    let result = [];
    for (const key of Object.keys(categoryTotals)) {
      result = result.concat([{"name": key, "value": categoryTotals[key]}]);
    }
    return result;
  }
  return {"transactions": transactions, "addTransaction": addTransaction, "deleteTransaction": deleteTransaction, "totalIncome": totalIncome, "totalExpenses": totalExpenses, "balance": balance, "expensesByCategory": getExpensesByCategory(), "businessIncome": businessIncome, "businessExpenses": businessExpenses, "personalIncome": personalIncome, "personalExpenses": personalExpenses, "taxReserve": taxReserve, "netProfit": netProfit};
}
