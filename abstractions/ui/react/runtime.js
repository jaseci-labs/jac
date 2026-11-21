// `@jac/runtime`: what a browser space's modules import, and how its app starts.
import React from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter, Routes, Route, Link as RouterLink, Navigate, Outlet, useLocation, useNavigate, useParams, useSearchParams } from "react-router-dom";
export * from "./session.js";

export { Navigate, Outlet, useLocation, useNavigate, useParams, useSearchParams };
export { useState, useEffect, useRef, useMemo, useCallback, useContext, createContext } from "react";
export const Link = RouterLink;
// Raw HTML as a child, which says so where it's used.
export function unsafe_html(html) {
    return React.createElement("span", { style: { display: "contents" }, dangerouslySetInnerHTML: { __html: String(html) } });
}

// Where the app is served, with no slash at its end: its space's `base`, which
// every route is under (startApp is told).
let served = "";

export function navigate(path) {
    window.history.pushState({}, "", served + path);
    window.dispatchEvent(new PopStateEvent("popstate"));
}

class ErrorBoundary extends React.Component {
    constructor(p) { super(p); this.state = { error: null }; }
    static getDerivedStateFromError(error) { return { error }; }
    componentDidCatch(error, info) { console.error("jac: a component failed", error, info); }
    render() {
        if (this.state.error) {
            return React.createElement("pre", { style: { padding: "2rem", whiteSpace: "pre-wrap" } }, String(this.state.error && this.state.error.stack || this.state.error));
        }
        return this.props.children;
    }
}

// A page, loaded when first shown, given its route's parameters: each by name,
// and the rest of the path (a `*` parameter) as its segments.
function lazyPage(r) {
    const L = React.lazy(() => r.load().then((m) => ({ default: m.page })));
    return function Page() {
        const ps = useParams();
        const props = {};
        for (const n of r.params || []) props[n] = ps[n];
        if (r.rest) props[r.rest] = (ps["*"] || "").split("/").filter(Boolean);
        return React.createElement(React.Suspense, { fallback: null }, React.createElement(L, props));
    };
}

export function startApp({ routes, layout, entry, base }) {
    served = (base || "/").replace(/\/+$/, "");
    const rs = routes.map((r) => React.createElement(Route, { key: r.path, path: r.path, element: React.createElement(lazyPage(r)) }));
    const tree = layout ? [React.createElement(Route, { key: "$layout", element: React.createElement(layout) }, ...rs)] : rs;
    const Wrap = entry && entry.app ? entry.app : React.Fragment;
    const app = React.createElement(ErrorBoundary, null,
        React.createElement(BrowserRouter, { basename: served || "/" },
            React.createElement(Wrap, null, React.createElement(Routes, null, ...tree))));
    createRoot(document.getElementById("root")).render(app);
}
