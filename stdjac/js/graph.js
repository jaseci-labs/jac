// The graph a `node` space keeps: nodes, edges and walkers as native
// code runs them (rt/impl/core.impl.jac's rt_spawn), which compiled modules
// import as `$g` when they use it. A walk is a queue of what's visited and a
// stack of where it is, a node's exit abilities running after what it visited.
// Which abilities run where is what compiler/analysis/dispatch planned, as data js_gen
// gives each class, in the shape the Python host's runtime reads
// (rt/stdjac/py/_jac.py): a walker class's `$plan`, for entry and exit, is
// whether the node's abilities run first, its own abilities by the class id
// of the node (or edge) they run at, and its untyped ones, which run once as
// the walk starts and ends; a node or edge class's `$visits`, for entry and
// exit, its abilities by the class id of the walker they run for. `$id` is a
// class's id. After each ability, a `skip` ends the node's (its flag
// cleared), a `disengage` the walk. Nothing here decides which ability runs:
// it looks up and calls. The graph is in memory: one root, and one shared.
import { Obj, TypeError, ValueError, exc, jid_give, jid_text, typeName } from "./core.js";

// The graph's own classes, which a program's nodes, edges and walkers extend.
function graphClass(C, name, visits) {
    C.$name = name; C.$key = name; C.$fields = []; C.$ctor = []; C.$identity = true;
    if (visits) C.$visits = [{}, {}];
    return C;
}
// A node and an edge take their id as they are made (core.js's jid_give).
export const Node = graphClass(class Node extends Obj { constructor() { super(); jid_give(this); } init() {} }, "Node", true);
export const Edge = graphClass(class Edge extends Obj { constructor() { super(); jid_give(this); } init() {} }, "Edge", true);
export const GenericEdge = graphClass(class GenericEdge extends Edge {}, "GenericEdge", true);
export const Walker = graphClass(class Walker extends Obj {
    init() {}
    // What its walks reported, every one of them.
    get reports() { return walkOf(this).reports; }
    // A walker that declares its reports (`has reports: list[T]`) holds
    // them as a field of its own.
    set reports(v) { Object.defineProperty(this, "reports", { value: v, writable: true, enumerable: true, configurable: true }); }
}, "Walker", false);
Walker.$plan = [[false, {}, []], [true, {}, []]];
export const Root = graphClass(class Root extends Node {
    // The one graph the space shares across callers (`root.shared`).
    get shared() { return shared; }
}, "Root", true);

// The ids the program gives the graph's own classes.
export function ids(node, root, generic) { Node.$id = node; Root.$id = root; GenericEdge.$id = generic; }

// Whose graph `root` means now, and the shared one.
let current = new Root().$init();
const shared = new Root().$init();
export const root = () => current;

// A walker's state, which native code keeps in its object's header: its flag
// (1 disengaged, 2 skipping the rest of a node), what's queued to visit and
// how far it got, and what it reported.
const walks = new WeakMap();
function walkOf(w) {
    let s = walks.get(w);
    if (s === undefined) walks.set(w, (s = { flag: 0, queue: [], head: 0, reports: [] }));
    return s;
}
export const reports = (w) => walkOf(w).reports;

// Each node's edges, out and in, in the order they were made.
const edges = new WeakMap();
function edgesOf(n) {
    let e = edges.get(n);
    if (e === undefined) edges.set(n, (e = [[], []]));
    return e;
}
const nodes = (x) => (Array.isArray(x) ? x : [x]);
// An edge's end, which its fields (its repr, its dir()) don't list.
const end = (e, which, n) => Object.defineProperty(e, which, { value: n, writable: true, configurable: true });

// `left ++> right` (op "out"), `<++` ("in") or `<++>` ("any"): an edge each
// way it points, made by `make` (a GenericEdge without one). Its value is
// `right`.
export function connect(left, right, make, op) {
    for (const a of nodes(left)) {
        for (const b of nodes(right)) {
            const pairs = op === "out" ? [[a, b]] : op === "in" ? [[b, a]] : [[a, b], [b, a]];
            for (const [src, dst] of pairs) {
                const e = make ? make() : new GenericEdge().$init();
                // An edge the program holds, given to a second connect.
                if (e.__src__ != null) throw exc(ValueError, "an edge connects one pair of nodes, and this one is already connected");
                end(e, "__src__", src);
                end(e, "__dst__", dst);
                edgesOf(src)[0].push(e);
                edgesOf(dst)[1].push(e);
            }
        }
    }
    return right;
}

// An edge reference's direction, as check records it (EdgeOp.aux).
const OUT = 0, IN = 1;
const kindOf = (kind) => (e) => kind === undefined || e instanceof kind;

// `[src -->]`: the nodes (or with `edgesOnly`, the edges) one step away in
// `dir`, along edges of class `kind` (any edge without one): each node once,
// however many edges reach it.
export function refs(src, dir, kind, edgesOnly) {
    const out = [];
    const ok = kindOf(kind);
    for (const n of nodes(src)) {
        const [outs, ins] = edgesOf(n);
        const ahead = dir !== IN ? outs.filter(ok) : [];
        const back = dir !== OUT ? ins.filter(ok) : [];
        if (edgesOnly) {
            // Each edge once: one from `n` to itself is among `ahead`.
            out.push(...ahead, ...back.filter((e) => dir === IN || e.__src__ !== n));
            continue;
        }
        const seen = new Set();
        for (const m of [...ahead.map((e) => e.__dst__), ...back.map((e) => e.__src__)]) {
            if (!seen.has(m)) { seen.add(m); out.push(m); }
        }
    }
    return out;
}

// Takes each of `es` out of the graph: that edge itself, never another equal
// to it. It has no ends again, as before it was connected (one that is not
// connected is in no node's lists).
export function remove_edges(es) {
    for (const e of es) {
        if (e.__src__ == null) continue;
        const outs = edgesOf(e.__src__)[0], ins = edgesOf(e.__dst__)[1];
        outs.splice(0, outs.length, ...outs.filter((x) => x !== e));
        ins.splice(0, ins.length, ...ins.filter((x) => x !== e));
        end(e, "__src__", undefined);
        end(e, "__dst__", undefined);
    }
}

// `left del --> right`: the edges between them of class `kind`, as the arrow
// points (`dir`), as rt_disconnect does.
export function disconnect(left, right, dir, kind) {
    const ok = kindOf(kind);
    for (const a of nodes(left)) {
        for (const b of nodes(right)) {
            if (dir !== IN) remove_edges(edgesOf(a)[0].filter((e) => ok(e) && e.__dst__ === b));
            if (dir !== OUT) remove_edges(edgesOf(b)[0].filter((e) => ok(e) && e.__dst__ === a));
        }
    }
}

// jid(x): a node's or an edge's id; only what a graph keeps has one.
export function jid(x) {
    if (!(x instanceof Node || x instanceof Edge)) throw exc(TypeError, "jid() takes a node or an edge, not '" + typeName(x) + "'");
    return jid_text(x);
}

// After an ability: whether the rest at this node is skipped (a `skip`, whose
// flag is cleared, so the walk goes on) or the walk disengaged.
function ran(s) {
    if (s.flag) {
        if (s.flag === 2) s.flag = 0;
        return true;
    }
    return false;
}

const NONE = [];
// Walker `w`'s and `cur`'s abilities, as `w` enters (phase 0) or leaves (1)
// `cur`, in the order planned.
function at(w, s, cur, phase) {
    const [nodesFirst, mine] = w.constructor.$plan[phase];
    const own = mine[cur.constructor.$id] || NONE;
    const theirs = cur.constructor.$visits[phase][w.constructor.$id] || NONE;
    if (nodesFirst) for (const f of theirs) { f.call(cur, w); if (ran(s)) return; }
    for (const f of own) { f.call(w, cur); if (ran(s)) return; }
    if (!nodesFirst) for (const f of theirs) { f.call(cur, w); if (ran(s)) return; }
}

const hasExit = (w, cur) => !!(w.constructor.$plan[1][1][cur.constructor.$id] || cur.constructor.$visits[1][w.constructor.$id]);

function whole(w, s, start, phase) {
    for (const f of w.constructor.$plan[phase][2]) { f.call(w, start); if (ran(s)) return; }
}

function dequeue(s) { return s.head < s.queue.length ? s.queue[s.head++] : undefined; }

// Walker `w`'s walk from `start` (check put the walker first): `w`.
export function spawn(w, start) {
    const s = walkOf(w);
    s.flag = 0;
    s.queue = [start];
    s.head = 0;
    whole(w, s, start, 0);
    const stack = [];
    while (s.flag === 0) {
        if (stack.length === 0) {
            const next = dequeue(s);
            if (next === undefined) { whole(w, s, start, 1); break; }
            stack.push([next, 0]);
            continue;
        }
        const top = stack[stack.length - 1];
        const [cur, phase] = top;
        if (phase === 0) {
            at(w, s, cur, 0);
            top[1] = 1;
        } else if (phase === 1) {
            const next = dequeue(s);
            if (next === undefined) top[1] = 2;
            else if (hasExit(w, cur)) stack.push([next, 0]);
            else stack[stack.length - 1] = [next, 0];
        } else {
            at(w, s, cur, 1);
            stack.pop();
        }
    }
    s.queue = [];
    s.head = 0;
    return w;
}

// `visit` of the list `items`, at position `pos` of what's left to visit
// (counted from its end when negative, -1 its back), as rt_visit_at does:
// whether there was anything to visit.
export function visit(w, items, pos) {
    if (items.length === 0) return false;
    const s = walkOf(w);
    const left = s.queue.length - s.head;
    if (pos < -left) pos = 0;
    else if (pos < 0) pos = pos + left + 1;
    if (pos > left) pos = left;
    s.queue.splice(s.head + pos, 0, ...items);
    return true;
}

// `visit` of one node or edge, which may be None (nothing to visit).
export const visit_one = (w, target, pos) => visit(w, target === undefined ? [] : [target], pos);
export function report(w, v) { walkOf(w).reports.push(v); }
export function skip(w) { walkOf(w).flag = 2; }
export function disengage(w) { walkOf(w).flag = 1; }
