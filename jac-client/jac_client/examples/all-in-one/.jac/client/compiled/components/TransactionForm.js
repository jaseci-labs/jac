import {__jacJsx, __jacSpawn} from "@jac-client/utils";
import { useState } from "react";
import { useBudgetContext } from "../context/BudgetContext.js";
import { CATEGORIES, CATEGORY_LABELS } from "../constants/categories.js";
import { CLIENTS } from "../constants/clients.js";
export function TransactionForm() {
  let [description, setDescription] = useState("");
  let [amount, setAmount] = useState("");
  let [category, setCategory] = useState("OTHER");
  let [txType, setTxType] = useState("expense");
  let [isBusiness, setIsBusiness] = useState(false);
  let [clientName, setClientName] = useState("");
  let budget = useBudgetContext();
  function handleSubmit(e) {
    e.preventDefault();
    let trimmedDesc = description.trim();
    if (trimmedDesc === "" || amount === "") {
      return;
    }
    let parsedAmount = parseFloat(amount);
    if (isNaN(parsedAmount) || parsedAmount <= 0) {
      return;
    }
    budget["addTransaction"](trimmedDesc, parsedAmount, category, txType, isBusiness, clientName);
    setDescription("");
    setAmount("");
    setCategory("OTHER");
    setIsBusiness(false);
    setClientName("");
  }
  let availableCategories = CATEGORIES.filter(cat => {
    if (txType === "income") {
      return cat === "INCOME";
    }
    return cat !== "INCOME";
  });
  let showClientDropdown = txType === "income" && isBusiness;
  return __jacJsx("form", {"className": "transaction-form", "onSubmit": handleSubmit}, [__jacJsx("div", {"className": "form-row"}, [__jacJsx("div", {"className": "form-group type-toggle"}, [__jacJsx("button", {"type": "button", "className": txType === "expense" ? "toggle-btn active" : "toggle-btn", "onClick": () => setTxType("expense")}, ["Expense"]), __jacJsx("button", {"type": "button", "className": txType === "income" ? "toggle-btn active income" : "toggle-btn", "onClick": () => setTxType("income")}, ["Income"])]), __jacJsx("div", {"className": "form-group business-toggle"}, [__jacJsx("button", {"type": "button", "className": isBusiness ? "toggle-btn active" : "toggle-btn", "onClick": () => setIsBusiness(true)}, ["Business"]), __jacJsx("button", {"type": "button", "className": !isBusiness ? "toggle-btn active" : "toggle-btn", "onClick": () => setIsBusiness(false)}, ["Personal"])])]), __jacJsx("div", {"className": "form-row"}, [__jacJsx("div", {"className": "form-group"}, [__jacJsx("label", {"htmlFor": "description"}, ["Description"]), __jacJsx("input", {"id": "description", "type": "text", "value": description, "onChange": e => {
    setDescription(e.target.value);
  }, "placeholder": "Enter description...", "className": "form-input"}, [])]), __jacJsx("div", {"className": "form-group"}, [__jacJsx("label", {"htmlFor": "amount"}, ["Amount"]), __jacJsx("input", {"id": "amount", "type": "number", "value": amount, "onChange": e => {
    setAmount(e.target.value);
  }, "placeholder": "0.00", "min": "0", "step": "0.01", "className": "form-input"}, [])]), __jacJsx("div", {"className": "form-group"}, [__jacJsx("label", {"htmlFor": "category"}, ["Category"]), __jacJsx("select", {"id": "category", "value": category, "onChange": e => {
    setCategory(e.target.value);
  }, "className": "form-select"}, [availableCategories.map(cat => {
    return __jacJsx("option", {"key": cat, "value": cat}, [CATEGORY_LABELS[cat]]);
  })])]), showClientDropdown && __jacJsx("div", {"className": "form-group"}, [__jacJsx("label", {"htmlFor": "client"}, ["Client"]), __jacJsx("select", {"id": "client", "value": clientName, "onChange": e => {
    setClientName(e.target.value);
  }, "className": "form-select"}, [__jacJsx("option", {"value": ""}, ["Select Client (Optional)"]), CLIENTS.map(client => {
    return __jacJsx("option", {"key": client, "value": client}, [client]);
  })])]), __jacJsx("div", {"className": "form-group"}, [__jacJsx("label", {}, ["Action"]), __jacJsx("button", {"type": "submit", "className": "submit-btn"}, ["Add ", txType[0].toUpperCase() + txType.slice(1)])])])]);
}
