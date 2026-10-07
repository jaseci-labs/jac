// WebSocket E2E tests — js_engine engine
//
// Spins up a WebSocketServer + N clients in one process and validates
// connection, messaging, broadcast, and graceful shutdown via check/checkTruthy.

var _passed = 0;
var _failed = 0;

function check(id, desc, actual, expected) {
    if (actual === expected) {
        console.log("OK  " + id + "  " + desc);
        _passed = _passed + 1;
    } else {
        console.log("FAIL " + id + "  " + desc);
        console.log("     expected: " + expected);
        console.log("     actual:   " + actual);
        _failed = _failed + 1;
    }
}

function checkTruthy(id, desc, actual) {
    if (actual) {
        console.log("OK  " + id + "  " + desc);
        _passed = _passed + 1;
    } else {
        console.log("FAIL " + id + "  " + desc);
        console.log("     expected truthy, got: " + String(actual));
        _failed = _failed + 1;
    }
}

var WebSocketServer = require("ws").WebSocketServer;

var PORT = 19800;
var N = 3;          // number of clients
var ROUNDS = 2;     // messages each client sends
var DELAY = 150;    // ms between messages
var nextId = 1;

// Tracking data for assertions
var serverConnections = 0;
var serverMessagesReceived = 0;
var clientMessagesReceived = [];  // per-client count
var clientGotId = [];             // did each client receive its id msg?
var clientCloseCode = [];         // close codes seen by clients
var serverCloseCount = 0;
var serverShutdown = false;

// ── Server ───────────────────────────────────────────────────────────────────

var wss = new WebSocketServer({ port: PORT });

// 1. Server created
checkTruthy(1, "WebSocketServer created", wss);
check(2, "wss.clients is a Set", wss.clients instanceof Set, true);

wss.on("connection", function (ws) {
    var id = nextId;
    nextId = nextId + 1;
    ws._chatId = id;
    serverConnections = serverConnections + 1;

    ws.send(JSON.stringify({ type: "id", id: id }));

    wss.clients.forEach(function (c) {
        if (c !== ws && c.readyState === WebSocket.OPEN) {
            c.send(JSON.stringify({ type: "join", id: id }));
        }
    });

    ws.on("message", function (raw) {
        serverMessagesReceived = serverMessagesReceived + 1;
        var msg = JSON.parse(raw);

        wss.clients.forEach(function (c) {
            if (c.readyState !== WebSocket.OPEN) { return; }
            if (msg.to === 0 || c._chatId === msg.to) {
                c.send(JSON.stringify({ type: "msg", from: id, text: msg.text }));
            }
        });
    });

    ws.on("close", function (code) {
        serverCloseCount = serverCloseCount + 1;

        wss.clients.forEach(function (c) {
            if (c.readyState === WebSocket.OPEN) {
                c.send(JSON.stringify({ type: "leave", id: id }));
            }
        });

        if (wss.clients.size === 0) {
            serverShutdown = true;
            wss.close(function () {
                maybeRunFinalChecks();
            });
        }
    });
});

// ── Clients ──────────────────────────────────────────────────────────────────

var closed = 0;

function chatLoop(state) {
    if (state.sent >= ROUNDS) {
        state.ws.close(1000, "done");
        return;
    }

    var target = 0; // broadcast
    state.ws.send(JSON.stringify({ to: target, text: "msg" + state.sent }));
    state.sent = state.sent + 1;

    setTimeout(function () { chatLoop(state); }, DELAY);
}

function makeClient(index) {
    var state = { ws: null, id: -1, sent: 0, received: 0, gotId: false };
    var ws = new WebSocket("ws://127.0.0.1:" + PORT);
    state.ws = ws;

    ws.onopen = function () {
        // 3,4,5. Client connections opened
        check(3 + index, "client " + index + " onopen fires, readyState=OPEN",
              ws.readyState, WebSocket.OPEN);
    };

    ws.onmessage = function (ev) {
        var msg = JSON.parse(ev.data);
        state.received = state.received + 1;

        if (msg.type === "id") {
            state.id = msg.id;
            state.gotId = true;
            setTimeout(function () { chatLoop(state); }, DELAY * (index + 1));
        }
    };

    ws.onclose = function (ev) {
        clientMessagesReceived[index] = state.received;
        clientGotId[index] = state.gotId;
        clientCloseCode[index] = ev.code;
        closed = closed + 1;

        if (closed >= N) {
            // Small delay so server's close handler fires first
            setTimeout(function () {
                maybeRunFinalChecks();
            }, 300);
        }
    };
}

// ── Final checks (run once all clients disconnect AND server shuts down) ─────

var finalRan = false;
function maybeRunFinalChecks() {
    if (finalRan) { return; }
    // Both conditions must be met: all clients closed + server shutdown
    if (closed < N || !serverShutdown) { return; }
    finalRan = true;

    // 6. All N clients connected to server
    check(6, "server saw " + N + " connections", serverConnections, N);

    // 7. Server received expected number of messages (N clients * ROUNDS each)
    check(7, "server received N*ROUNDS messages", serverMessagesReceived, N * ROUNDS);

    // 8. Server saw all N close events
    check(8, "server saw " + N + " close events", serverCloseCount, N);

    // 9. Server shutdown triggered
    check(9, "server shutdown after all clients left", serverShutdown, true);

    // 10,11,12. Each client received its id assignment
    for (var i = 0; i < N; i = i + 1) {
        check(10 + i, "client " + i + " received id assignment", clientGotId[i], true);
    }

    // 13,14,15. Each client received at least ROUNDS messages (broadcasts go to all)
    for (var j = 0; j < N; j = j + 1) {
        checkTruthy(13 + j, "client " + j + " received >= " + ROUNDS + " messages",
                    clientMessagesReceived[j] >= ROUNDS);
    }

    // 16,17,18. Each client closed with code 1000
    for (var k = 0; k < N; k = k + 1) {
        check(16 + k, "client " + k + " close code 1000", clientCloseCode[k], 1000);
    }

    // 19. wss.clients empty after shutdown
    check(19, "wss.clients.size === 0 after shutdown", wss.clients.size, 0);

    // ── Summary ──────────────────────────────────────────────────────────────
    console.log("\n=== WebSocket E2E tests: " + _passed + " passed, " + _failed + " failed ===");
}

// Spawn clients after a short delay to let the server start accepting
setTimeout(function () {
    for (var i = 0; i < N; i = i + 1) {
        makeClient(i);
    }
}, 100);
