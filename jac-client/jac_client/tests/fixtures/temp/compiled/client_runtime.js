import * as React from "react";
import * as ReactDOM from "react-dom/client";
import { HashRouter as ReactRouterHashRouter, Routes as ReactRouterRoutes, Route as ReactRouterRoute, Link as ReactRouterLink, Navigate as ReactRouterNavigate, useNavigate as reactRouterUseNavigate, useLocation as reactRouterUseLocation, useParams as reactRouterUseParams } from "react-router-dom";
function __jacJsx(tag, props, children) {
  if (tag === null) {
    tag = React.Fragment;
  }
  let childrenArray = [];
  if (children !== null) {
    if (Array.isArray(children)) {
      childrenArray = children;
    } else {
      childrenArray = [children];
    }
  }
  let reactChildren = [];
  for (const child of childrenArray) {
    if (child !== null) {
      reactChildren.push(child);
    }
  }
  if (reactChildren.length > 0) {
    let args = [tag, props];
    for (const child of reactChildren) {
      args.push(child);
    }
    return React.createElement.apply(React, args);
  } else {
    return React.createElement(tag, props);
  }
}
const Router = ReactRouterHashRouter;
const Routes = ReactRouterRoutes;
const Route = ReactRouterRoute;
const Link = ReactRouterLink;
const Navigate = ReactRouterNavigate;
const useNavigate = reactRouterUseNavigate;
const useLocation = reactRouterUseLocation;
const useParams = reactRouterUseParams;
function useRouter() {
  let navigate = reactRouterUseNavigate();
  let location = reactRouterUseLocation();
  let params = reactRouterUseParams();
  return {"navigate": navigate, "location": location, "params": params, "pathname": location.pathname, "search": location.search, "hash": location.hash};
}
function navigate(path) {
  window.location.hash = "#" + path;
}
async function __jacSpawn(left, right, fields) {
  let token = __getLocalStorage("jac_token");
  let url = `/walker/${left}`;
  if (right !== "") {
    url = `/walker/${left}/${right}`;
  }
  let response = await fetch(url, {"method": "POST", "accept": "application/json", "headers": {"Content-Type": "application/json", "Authorization": token ? `Bearer ${token}` : ""}, "body": JSON.stringify(fields)});
  if (!response.ok) {
    let error_text = await response.json();
    throw new Error(`Walker ${walker} failed: ${error_text}`);
  }
  return await response.json();
}
function jacSpawn(left, right, fields) {
  return __jacSpawn(left, right, fields);
}
async function __jacCallFunction(function_name, args) {
  let token = __getLocalStorage("jac_token");
  let response = await fetch(`/function/${function_name}`, {"method": "POST", "headers": {"Content-Type": "application/json", "Authorization": token ? `Bearer ${token}` : ""}, "body": JSON.stringify({"args": args})});
  if (!response.ok) {
    let error_text = await response.text();
    throw new Error(`Function ${function_name} failed: ${error_text}`);
  }
  let data = JSON.parse(await response.text());
  return data["result"];
}
async function jacSignup(username, password) {
  let response = await fetch("/user/create", {"method": "POST", "headers": {"Content-Type": "application/json"}, "body": JSON.stringify({"username": username, "password": password})});
  if (response.ok) {
    let data = JSON.parse(await response.text());
    let token = data["token"];
    if (token) {
      __setLocalStorage("jac_token", token);
      return {"success": true, "token": token, "username": username};
    }
    return {"success": false, "error": "No token received"};
  } else {
    let error_text = await response.text();
    try {
      let error_data = JSON.parse(error_text);
      return {"success": false, "error": error_data["error"] !== null ? error_data["error"] : "Signup failed"};
    } catch {
      return {"success": false, "error": error_text};
    }
  }
}
async function jacLogin(username, password) {
  let response = await fetch("/user/login", {"method": "POST", "headers": {"Content-Type": "application/json"}, "body": JSON.stringify({"username": username, "password": password})});
  if (response.ok) {
    let data = JSON.parse(await response.text());
    let token = data["token"];
    if (token) {
      __setLocalStorage("jac_token", token);
      return true;
    }
  }
  return false;
}
function jacLogout() {
  __removeLocalStorage("jac_token");
}
function jacIsLoggedIn() {
  let token = __getLocalStorage("jac_token");
  return token !== null && token !== "";
}
function __getLocalStorage(key) {
  let storage = globalThis.localStorage;
  return storage ? storage.getItem(key) : "";
}
function __setLocalStorage(key, value) {
  let storage = globalThis.localStorage;
  if (storage) {
    storage.setItem(key, value);
  }
}
function __removeLocalStorage(key) {
  let storage = globalThis.localStorage;
  if (storage) {
    storage.removeItem(key);
  }
}
export { Link, Navigate, Route, Router, Routes, __getLocalStorage, __jacCallFunction, __jacJsx, __jacSpawn, __removeLocalStorage, __setLocalStorage, jacIsLoggedIn, jacLogin, jacLogout, jacSignup, jacSpawn, navigate, useLocation, useNavigate, useParams, useRouter };
