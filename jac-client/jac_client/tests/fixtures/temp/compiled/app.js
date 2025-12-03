import {__jacJsx, __jacSpawn} from "@jac-client/utils";
import { useState, useEffect } from "react";
import { Router, Routes, Route, Link, useLocation } from "@jac-client/utils";
import "./styles.css";
import { CustomButton } from "./components/button.js";
import { CustomButtonRoot } from "./button.js";
import { Card } from "./components/Card.tsx";
function Home() {
  let [count, setCount] = useState(0);
  let [pingResult, setPingResult] = useState("");
  let [serverMessage, setServerMessage] = useState("");
  let [lastTodoMessage, setLastTodoMessage] = useState("");
  useEffect(() => {
    console.log("Home count changed: ", count);
  }, [count]);
  async function handlePing() {
    let result = await __jacSpawn("ping_server", "", {});
    if (result.reports && result.reports.length > 0) {
      setPingResult(result.reports[0][0]);
    }
  }
  async function loadServerMessage() {
    let result = await __jacSpawn("get_server_message", "", {});
    if (result.reports && result.reports.length > 0) {
      setServerMessage(result.reports[0][0]);
    }
  }
  async function handleCreateSampleTodo() {
    let result = await __jacSpawn("create_todo", "", {"text": "Sample todo from all-in-one app"});
    if (result.reports && result.reports.length > 0) {
      let todo = result.reports[0][0];
      setLastTodoMessage("Created Todo: " + todo.text);
      console.log("Created Todo node:", todo);
    }
  }
  useEffect(() => {
    loadServerMessage();
  }, []);
  return __jacJsx("div", {"style": {"padding": "2rem", "fontFamily": "system-ui, -apple-system, sans-serif"}}, [__jacJsx("h1", {}, ["🍔 Router + Styling + Assets Demo"]), __jacJsx("p", {}, ["This home page combines", " ", __jacJsx("strong", {}, ["React Router,"]), " ", __jacJsx("strong", {}, ["pure CSS styling,"]), " ", __jacJsx("strong", {}, ["static", " assets"]), " ", "and", " ", __jacJsx("strong", {}, ["nested folder imports"])]), __jacJsx("div", {"className": "container"}, [__jacJsx("h2", {"style": {"color": "white", "textShadow": "2px 2px 4px rgba(0,0,0,0.6)"}}, ["CSS Background Image"]), __jacJsx("p", {"style": {"color": "white", "maxWidth": "480px", "textShadow": "1px 1px 3px rgba(0,0,0,0.7)"}}, ["This section uses the burger image as a background via CSS, just like the", " ", __jacJsx("code", {}, ["as", "set-serving/css-with-image"]), " ", "example."])]), __jacJsx(Card, {"title": "TypeScript Card Component", "description": "This card is built with TypeScript and demonstrates type-safe component usage in Jac", "variant": "highlighted"}, [__jacJsx("p", {"style": {"margin": "0.5rem 0", "color": "#374151"}}, ["This is a TypeScript component imported and used in Jac code!"])]), __jacJsx("div", {"className": "card"}, [__jacJsx("h3", {}, ["Direct &lt;img&gt; asset"]), __jacJsx("img", {"src": "/static/assets/burger.png", "alt": "Burger asset served by Jac", "className": "burgerImage"}, []), __jacJsx("p", {"style": {"marginTop": "0.75rem", "color": "#555"}}, ["This image is served from the project", " ", __jacJsx("code", {}, ["as", "sets/"]), " ", "folder using the", " ", __jacJsx("code", {}, ["/static/assets/"]), " ", "path."])]), __jacJsx("div", {"style": {"marginTop": "2rem"}}, [__jacJsx("h3", {}, ["Counter with pure CSS classes"]), __jacJsx("p", {}, ["You've clicked the burger", " ", __jacJsx("strong", {}, [count]), " ", "times."]), __jacJsx("button", {"onClick": e => {
    setCount(count + 1);
  }, "style": {"padding": "0.6rem 1.4rem", "fontSize": "1rem", "backgroundColor": "#ff6b35", "color": "white", "border": "none", "borderRadius": "6px", "cursor": "pointer", "boxShadow": "0 2px 4px rgba(0,0,0,0.2)"}}, ["Click the Burger! 🍔"])]), __jacJsx("div", {"style": {"marginTop": "2rem"}}, [__jacJsx("h3", {}, ["Backend Walkers"]), __jacJsx("p", {}, ["Basic example walkers:", " ", __jacJsx("code", {}, ["ping_server"]), " ", "and", " ", __jacJsx("code", {}, ["get_server_message"])]), __jacJsx("button", {"onClick": e => {
    handlePing();
  }, "style": {"padding": "0.5rem 1.2rem", "marginRight": "0.75rem", "backgroundColor": "#3b82f6", "color": "white", "border": "none", "borderRadius": "6px", "cursor": "pointer"}}, ["Ping Backend"]), __jacJsx("button", {"onClick": e => {
    handleCreateSampleTodo();
  }, "style": {"padding": "0.5rem 1.2rem", "backgroundColor": "#10b981", "color": "white", "border": "none", "borderRadius": "6px", "cursor": "pointer"}}, ["Create Sample Todo"]), pingResult && __jacJsx("span", {"style": {"marginLeft": "0.5rem", "color": "#374151"}}, ["Result:", " ", __jacJsx("code", {}, [pingResult])]), serverMessage && __jacJsx("p", {"style": {"marginTop": "0.75rem", "color": "#374151"}}, ["Message:", " ", __jacJsx("code", {}, [serverMessage])]), lastTodoMessage && __jacJsx("p", {"style": {"marginTop": "0.5rem", "color": "#111827"}}, [lastTodoMessage])])]);
}
function NestedImportsDemo() {
  return __jacJsx("div", {"style": {"padding": "2rem", "fontFamily": "system-ui, -apple-system, sans-serif"}}, [__jacJsx("h1", {}, ["📁 Nested Folder Imports"]), __jacJsx("p", {}, ["This page mirrors the", " ", __jacJsx("code", {}, ["nested-folders/nested-basic"]), " ", "example by importing components from both", " ", __jacJsx("code", {}, ["components.button"]), " ", "and", " ", __jacJsx("code", {}, ["button"])]), __jacJsx("p", {"style": {"marginTop": "0.75rem"}}, ["Both buttons below are rendered via relative imports:"]), __jacJsx("div", {"style": {"display": "flex", "gap": "1rem", "marginTop": "1.5rem"}}, [__jacJsx(CustomButton, {}, []), __jacJsx(CustomButtonRoot, {}, [])])]);
}
function NotFound() {
  return __jacJsx("div", {"style": {"padding": "2rem", "textAlign": "center", "fontFamily": "system-ui, -apple-system, sans-serif"}}, [__jacJsx("h1", {}, ["🔍 404 - Page Not Found"]), __jacJsx("p", {}, ["The page you are looking for does not exist."]), __jacJsx(Link, {"to": "/"}, ["← Back to Home"])]);
}
function Navigation() {
  let location = useLocation();
  function linkStyle(path) {
    let isActive = location.pathname === path;
    return {"padding": "0.5rem 1rem", "textDecoration": "none", "color": isActive ? "#0066cc" : "#333", "fontWeight": isActive ? "bold" : "normal", "backgroundColor": isActive ? "#e3f2fd" : "transparent", "borderRadius": "4px", "display": "inline-block"};
  }
  return __jacJsx("nav", {"style": {"padding": "1rem", "backgroundColor": "#f5f5f5", "marginBottom": "2rem", "boxShadow": "0 2px 4px rgba(0,0,0,0.1)"}}, [__jacJsx("div", {"style": {"maxWidth": "1200px", "margin": "0 auto", "display": "flex", "gap": "1rem", "alignItems": "center"}}, [__jacJsx(Link, {"to": "/", "style": linkStyle("/")}, ["Home"]), __jacJsx(Link, {"to": "/nested", "style": linkStyle("/nested")}, ["Nested Imports"])])]);
}
function app() {
  return __jacJsx(Router, {}, [__jacJsx("div", {"style": {"fontFamily": "system-ui, -apple-system, sans-serif"}}, [__jacJsx(Navigation, {}, []), __jacJsx("div", {"style": {"maxWidth": "960px", "margin": "0 auto", "padding": "0 1rem 3rem 1rem"}}, [__jacJsx(Routes, {}, [__jacJsx(Route, {"path": "/", "element": __jacJsx(Home, {}, [])}, []), __jacJsx(Route, {"path": "/nested", "element": __jacJsx(NestedImportsDemo, {}, [])}, []), __jacJsx(Route, {"path": "*", "element": __jacJsx(NotFound, {}, [])}, [])])])])]);
}
export { Home, Navigation, NestedImportsDemo, NotFound, app };
