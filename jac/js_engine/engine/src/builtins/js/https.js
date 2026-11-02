// node:https — HTTPS client and server module (Node.js v24 parity)
// Reference: https://nodejs.org/docs/latest-v24.x/api/https.html

var EventEmitter = require("events");
var tlsModule = require("tls");
var httpModule = require("http");
var core = require("http_core");

var CRLF = core.CRLF;
var STATUS_CODES = httpModule.STATUS_CODES;
var METHODS = httpModule.METHODS;

function _parseUrl(urlStr) {
    if (typeof URL !== "undefined") {
        try {
            var u = new URL(urlStr);
            return {
                protocol: u.protocol,
                hostname: u.hostname,
                port: u.port || 443,
                path: u.pathname + (u.search || ""),
                pathname: u.pathname,
                search: u.search || ""
            };
        } catch (e) { /* fall through */ }
    }
    var result = { protocol: "https:", hostname: "localhost", port: 443, path: "/", pathname: "/", search: "" };
    var str = urlStr;
    var protoEnd = str.indexOf("://");
    if (protoEnd !== -1) {
        result.protocol = str.substring(0, protoEnd + 1);
        str = str.substring(protoEnd + 3);
    }
    var pathStart = str.indexOf("/");
    if (pathStart === -1) {
        result.hostname = str;
    } else {
        result.hostname = str.substring(0, pathStart);
        result.path = str.substring(pathStart);
        result.pathname = result.path;
        var qIdx = result.path.indexOf("?");
        if (qIdx !== -1) {
            result.pathname = result.path.substring(0, qIdx);
            result.search = result.path.substring(qIdx);
        }
    }
    var colonIdx = result.hostname.indexOf(":");
    if (colonIdx !== -1) {
        result.port = Number(result.hostname.substring(colonIdx + 1));
        result.hostname = result.hostname.substring(0, colonIdx);
    }
    return result;
}

function _mergeOptions(base, over) {
    var merged = {};
    var bk = Object.keys(base);
    for (var i = 0; i < bk.length; i++) { merged[bk[i]] = base[bk[i]]; }
    if (over) {
        var ok = Object.keys(over);
        for (var j = 0; j < ok.length; j++) { merged[ok[j]] = over[ok[j]]; }
    }
    return merged;
}

function _mergeTlsOptions(options) {
    var tlsOpts = {};
    if (options.ca) { tlsOpts.ca = options.ca; }
    if (options.cert) { tlsOpts.cert = options.cert; }
    if (options.key) { tlsOpts.key = options.key; }
    if (options.pfx) { tlsOpts.pfx = options.pfx; }
    if (options.passphrase) { tlsOpts.passphrase = options.passphrase; }
    if (options.ciphers) { tlsOpts.ciphers = options.ciphers; }
    if (options.rejectUnauthorized !== undefined) {
        tlsOpts.rejectUnauthorized = options.rejectUnauthorized;
    }
    if (options.servername !== undefined) { tlsOpts.servername = options.servername; }
    if (options.secureProtocol) { tlsOpts.secureProtocol = options.secureProtocol; }
    if (options.secureOptions !== undefined) { tlsOpts.secureOptions = options.secureOptions; }
    if (options.sessionIdContext) { tlsOpts.sessionIdContext = options.sessionIdContext; }
    if (options.honorCipherOrder !== undefined) { tlsOpts.honorCipherOrder = options.honorCipherOrder; }
    if (options.ecdhCurve) { tlsOpts.ecdhCurve = options.ecdhCurve; }
    if (options.dhparam) { tlsOpts.dhparam = options.dhparam; }
    if (options.crl) { tlsOpts.crl = options.crl; }
    return tlsOpts;
}

/**
 * https.ClientRequest — TLS transport via http.ClientRequest pattern.
 */
class ClientRequest extends httpModule.ClientRequest {
    constructor(options, cb) {
        if (typeof options === "string") {
            options = _parseUrl(options);
        }
        options = options || {};
        options.protocol = options.protocol || "https:";
        if (!options.port) { options.port = 443; }
        if (options.agent === undefined) { options.agent = globalAgent; }

        var tlsOpts = _mergeTlsOptions(options);
        var connectOpts = {
            host: options.hostname || options.host || "localhost",
            port: Number(options.port) || 443,
            servername: options.servername || options.hostname || options.host,
            rejectUnauthorized: options.rejectUnauthorized !== false
        };
        var ck = Object.keys(tlsOpts);
        for (var i = 0; i < ck.length; i++) {
            connectOpts[ck[i]] = tlsOpts[ck[i]];
        }
        connectOpts.hostname = connectOpts.host;
        options._connectOptions = connectOpts;
        var tlsCreate = function(opts, cb) {
            return tlsModule.connect(opts, cb);
        };
        options.createConnection = tlsCreate;
        options._createConnection = tlsCreate;

        super(options, cb);
        this._tlsOpts = tlsOpts;
    }
}

// Override connection path: use TLS in Agent for https
class Agent extends httpModule.Agent {
    constructor(options) {
        super(options);
        this.maxCachedSessions = options.maxCachedSessions !== undefined ?
            options.maxCachedSessions : 100;
        this.defaultPort = options.defaultPort || 443;
        this.protocol = options.protocol || "https:";
        this.servername = options.servername;
    }

    createConnection(options, cb) {
        var proxyMod = require("http_proxy");
        if (options && options._proxyConfig) {
            return proxyMod.createProxiedConnection(options, cb);
        }
        if (options && typeof options._createConnection === "function") {
            return options._createConnection(options, cb);
        }
        var opts = options || {};
        if (!opts.servername && opts.host) {
            var host = opts.host;
            if (host.indexOf(":") === -1 && host.match && !host.match(/^\d+\.\d+\.\d+\.\d+$/)) {
                opts.servername = host;
            }
        }
        return tlsModule.connect(opts, cb);
    }

    getName(options) {
        var base = httpModule.Agent.prototype.getName.call(this, options);
        if (options.ca || options.cert || options.ciphers) {
            return base + ":tls";
        }
        return base;
    }
}

var globalAgent = new Agent({ keepAlive: true, timeout: 5000 });

function Server(options, requestListener) {
    if (!(this instanceof Server)) {
        return new Server(options, requestListener);
    }
    if (typeof options === "function") {
        requestListener = options;
        options = {};
    }
    options = options || {};

    httpModule.Server.call(this, options, requestListener);

    var self = this;
    var tlsOpts = _mergeTlsOptions(options);
    if (options.cert) { tlsOpts.cert = options.cert; }
    if (options.key) { tlsOpts.key = options.key; }

    this._server = tlsModule.createServer(tlsOpts, function(socket) {
        self._onConnection(socket);
    });

    this._server.on("error", function(err) { self.emit("error", err); });
    this._server.on("listening", function() {
        self._listening = true;
        self.emit("listening");
    });
    this._server.on("close", function() {
        self._listening = false;
        self.emit("close");
    });
}
Server.prototype = Object.create(httpModule.Server.prototype);
Server.prototype.constructor = Server;

function createServer(options, requestListener) {
    return new Server(options, requestListener);
}

function request(url, options, cb) {
    if (typeof url === "string" && (options === undefined || typeof options === "function")) {
        cb = options;
        options = _parseUrl(url);
    } else if (typeof url === "string") {
        var parsed = _parseUrl(url);
        if (options) {
            var keys = Object.keys(options);
            for (var i = 0; i < keys.length; i++) {
                parsed[keys[i]] = options[keys[i]];
            }
        }
        options = parsed;
    } else if (url && typeof url === "object") {
        if (typeof options === "function") {
            cb = options;
            options = url;
        } else {
            options = _mergeOptions(url, options || {});
        }
    }
    if (typeof options === "function") {
        cb = options;
        options = {};
    }
    options.protocol = "https:";
    if (!options.port) { options.port = 443; }
    return new ClientRequest(options, cb);
}

function get(url, options, cb) {
    if (typeof options === "function") {
        cb = options;
        options = {};
    }
    if (typeof url === "string") {
        var parsed = _parseUrl(url);
        if (options) {
            var keys = Object.keys(options);
            for (var i = 0; i < keys.length; i++) {
                parsed[keys[i]] = options[keys[i]];
            }
        }
        options = parsed;
    } else if (typeof url === "object" && url !== null) {
        var merged = url;
        if (options) {
            var okeys = Object.keys(options);
            for (var oi = 0; oi < okeys.length; oi++) {
                merged[okeys[oi]] = options[okeys[oi]];
            }
        }
        options = merged;
    }
    options.method = "GET";
    var req = new ClientRequest(options, cb);
    req.end();
    return req;
}

module.exports = {
    Agent: Agent,
    Server: Server,
    ClientRequest: ClientRequest,
    IncomingMessage: httpModule.IncomingMessage,
    ServerResponse: httpModule.ServerResponse,
    OutgoingMessage: httpModule.OutgoingMessage,
    globalAgent: globalAgent,
    createServer: createServer,
    request: request,
    get: get,
    METHODS: METHODS,
    STATUS_CODES: STATUS_CODES,
    maxHeaderSize: httpModule.maxHeaderSize,
    validateHeaderName: httpModule.validateHeaderName,
    validateHeaderValue: httpModule.validateHeaderValue,
    checkHeaderName: httpModule.checkHeaderName,
    checkHeaderValue: httpModule.checkHeaderValue,
    setMaxIdleHTTPParsers: httpModule.setMaxIdleHTTPParsers,
    setGlobalProxyFromEnv: httpModule.setGlobalProxyFromEnv,
    getDefaultHighWaterMark: httpModule.getDefaultHighWaterMark,
    setDefaultHighWaterMark: httpModule.setDefaultHighWaterMark
};
