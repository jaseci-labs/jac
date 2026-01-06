import {__jacJsx, __jacSpawn} from "@jac-client/utils";
import { createContext, useContext } from "react";
import { useBudget } from "../hooks/useBudget.js";
export let BudgetContext = createContext(null);
export function BudgetProvider(props) {
  const {children} = props;
  let budget = useBudget();
  return __jacJsx(BudgetContext.Provider, {"value": budget}, [children]);
}
export function useBudgetContext() {
  let context = useContext(BudgetContext);
  if (context === null) {
    console.error("useBudgetContext must be used within BudgetProvider");
  }
  return context;
}