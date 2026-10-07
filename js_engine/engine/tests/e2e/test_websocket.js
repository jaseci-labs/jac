// WebSocket tests — js_engine engine
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

// ── 1. __ws bridge exists ────────────────────────────────────────────────────
check(1, "typeof __ws === 'object'", typeof __ws, "object");
check(2, "typeof __ws.acceptKey === 'function'", typeof __ws.acceptKey, "function");
check(3, "typeof __ws.randomKey === 'function'", typeof __ws.randomKey, "function");
check(4, "typeof __ws.sendFrame === 'function'", typeof __ws.sendFrame, "function");
check(5, "typeof __ws.createRecvBuf === 'function'", typeof __ws.createRecvBuf, "function");
check(6, "typeof __ws.recvBufDecode === 'function'", typeof __ws.recvBufDecode, "function");
check(7, "typeof __ws.recvBufExtract === 'function'", typeof __ws.recvBufExtract, "function");
check(8, "typeof __ws.recvBufConsume === 'function'", typeof __ws.recvBufConsume, "function");

// ── 2. Sec-WebSocket-Accept computation ──────────────────────────────────────
check(9, "acceptKey RFC 6455 test vector", __ws.acceptKey("dGhlIHNhbXBsZSBub25jZQ=="), "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=");

// ── 3. Random key generation ─────────────────────────────────────────────────
var _rk1 = __ws.randomKey();
check(10, "randomKey returns string", typeof _rk1, "string");
check(11, "randomKey length === 24", _rk1.length, 24);
check(12, "randomKey is different each time", __ws.randomKey() !== _rk1, true);

// ── 4. Receive buffer ────────────────────────────────────────────────────────
var _rbId = __ws.createRecvBuf();
check(13, "createRecvBuf returns number", typeof _rbId, "number");
check(14, "createRecvBuf returns positive id", _rbId > 0, true);

var _rbDec = __ws.recvBufDecode(__ws.createRecvBuf());
check(15, "recvBufDecode on empty buf is array", Array.isArray(_rbDec), true);
check(16, "recvBufDecode result length === 6", _rbDec.length, 6);
check(17, "recvBufDecode opcode === -1 for empty", _rbDec[0], -1);

// ── 5. Close payload ─────────────────────────────────────────────────────────
var _cp1 = __ws.makeClosePayload(1000, "normal");
check(18, "makeClosePayload typeof string", typeof _cp1, "string");
check(19, "makeClosePayload(1000,'normal') length === 8", _cp1.length, 8);
check(20, "makeClosePayload code high byte (1000 >> 8 === 3)", _cp1.charCodeAt(0), 3);
check(21, "makeClosePayload code low byte (1000 & 0xFF === 232)", _cp1.charCodeAt(1), 232);
check(22, "makeClosePayload reason === 'normal'", _cp1.substring(2), "normal");

var _cp2 = __ws.makeClosePayload(1001, "");
check(23, "makeClosePayload code-only length === 2", _cp2.length, 2);
check(24, "makeClosePayload(1001) high byte === 3", _cp2.charCodeAt(0), 3);
check(25, "makeClosePayload(1001) low byte === 233", _cp2.charCodeAt(1), 233);

// ── 6. WebSocket global ──────────────────────────────────────────────────────
check(26, "typeof WebSocket === 'function'", typeof WebSocket, "function");
check(27, "WebSocket.CONNECTING === 0", WebSocket.CONNECTING, 0);
check(28, "WebSocket.OPEN === 1", WebSocket.OPEN, 1);
check(29, "WebSocket.CLOSING === 2", WebSocket.CLOSING, 2);
check(30, "WebSocket.CLOSED === 3", WebSocket.CLOSED, 3);

// ── 7. Phase A: new methods exist ────────────────────────────────────────────
check(31, "typeof WebSocket.prototype.terminate === 'function'", typeof WebSocket.prototype.terminate, "function");
check(32, "typeof WebSocket.prototype.pong === 'function'", typeof WebSocket.prototype.pong, "function");
check(33, "typeof WebSocket.prototype.ping === 'function'", typeof WebSocket.prototype.ping, "function");
check(34, "typeof WebSocket.prototype.send === 'function'", typeof WebSocket.prototype.send, "function");
check(35, "typeof WebSocket.prototype.close === 'function'", typeof WebSocket.prototype.close, "function");

// ── 8. Phase A: ServerWebSocket new methods ──────────────────────────────────
var _wsServer = require("websocket_server");
check(36, "ServerWebSocket exported", typeof _wsServer.ServerWebSocket, "function");
check(37, "typeof ServerWebSocket.prototype.pong === 'function'", typeof _wsServer.ServerWebSocket.prototype.pong, "function");
check(38, "typeof ServerWebSocket.prototype.terminate === 'function'", typeof _wsServer.ServerWebSocket.prototype.terminate, "function");
check(39, "typeof ServerWebSocket.prototype.ping === 'function'", typeof _wsServer.ServerWebSocket.prototype.ping, "function");
check(40, "typeof ServerWebSocket.prototype.send === 'function'", typeof _wsServer.ServerWebSocket.prototype.send, "function");
check(41, "typeof ServerWebSocket.prototype.close === 'function'", typeof _wsServer.ServerWebSocket.prototype.close, "function");

// ── 9. Phase B: require("ws") module ─────────────────────────────────────────
var _ws = require("ws");
check(42, "require('ws') returns function", typeof _ws, "function");
check(43, "require('ws') === WebSocket", _ws === WebSocket, true);
check(44, "require('ws').WebSocket === WebSocket", _ws.WebSocket === WebSocket, true);
check(45, "typeof require('ws').WebSocketServer === 'function'", typeof _ws.WebSocketServer, "function");
check(46, "require('ws').default === WebSocket", _ws.default === WebSocket, true);

// ── 10. Phase B: WebSocketServer class ───────────────────────────────────────
var WSS = _ws.WebSocketServer;
check(47, "WebSocketServer is a function", typeof WSS, "function");

// noServer mode — no port, no http server
var _wss = new WSS({ noServer: true });
check(48, "WSS noServer: typeof handleUpgrade === 'function'", typeof _wss.handleUpgrade, "function");
check(49, "WSS noServer: typeof close === 'function'", typeof _wss.close, "function");
check(50, "WSS noServer: typeof address === 'function'", typeof _wss.address, "function");
check(51, "WSS noServer: clients is a Set", _wss.clients instanceof Set, true);
check(52, "WSS noServer: clients is empty", _wss.clients.size, 0);
check(53, "WSS noServer: options.noServer === true", _wss.options.noServer, true);
_wss.close();

// clientTracking: false
var _wss2 = new WSS({ noServer: true, clientTracking: false });
check(54, "WSS clientTracking=false: clients is null", _wss2.clients, null);
_wss2.close();

// path option preserved
var _wss3 = new WSS({ noServer: true, path: "/chat" });
check(55, "WSS path stored", _wss3._path, "/chat");
_wss3.close();

// EventEmitter integration
var _wssEmit = new WSS({ noServer: true });
var _evtFired = false;
_wssEmit.on("close", function() { _evtFired = true; });
_wssEmit.close();
check(56, "WSS emits 'close' on close()", _evtFired, true);

// ── Summary ──────────────────────────────────────────────────────────────────
console.log("\n=== WebSocket tests: " + _passed + " passed, " + _failed + " failed ===");
