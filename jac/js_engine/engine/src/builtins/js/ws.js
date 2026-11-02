// ws — Node.js `ws` library compatible module
// Phase B — exports WebSocket and WebSocketServer
//
// Usage:
//   var WebSocket = require("ws");
//   var { WebSocketServer } = require("ws");
//   var ws = new WebSocket("ws://localhost:8080");
//   var wss = new WebSocketServer({ port: 8080 });

var _wsServer = require("websocket_server");

module.exports = WebSocket;
module.exports.WebSocket = WebSocket;
module.exports.WebSocketServer = _wsServer.WebSocketServer;
module.exports.default = WebSocket;
