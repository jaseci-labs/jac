import {__jacJsx, __jacSpawn} from "@jac-client/utils";
import { Router, Routes, Route, Link } from "@jac-client/utils";
import { LandingPage } from "./pages/LandingPage.js";
import { BudgetPlanner } from "./pages/BudgetPlanner.js";
import { FeaturesTest } from "./pages/FeaturesTest.js";
import { BudgetProvider } from "./context/BudgetContext.js";
import "./styles.css";
export function app() {
  return __jacJsx(Router, {}, [__jacJsx(Routes, {}, [__jacJsx(Route, {"path": "/", "element": __jacJsx(LandingPage, {}, [])}, []), __jacJsx(Route, {"path": "/app", "element": __jacJsx(BudgetProvider, {}, [__jacJsx(BudgetPlanner, {}, [])])}, []), __jacJsx(Route, {"path": "/features", "element": __jacJsx(FeaturesTest, {}, [])}, [])])]);
}
