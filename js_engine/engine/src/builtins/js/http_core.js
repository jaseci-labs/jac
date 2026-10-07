// Shared HTTP/1.1 primitives for node:http and node:https (Node.js v24 semantics).
// Internal module — not part of the public Node API surface.

var CRLF = String.fromCharCode(13) + "\n";

// RFC 9110 §5.3 — duplicate singleton headers discarded unless joinDuplicateHeaders.
var DUPLICATE_DISCARD = {
    "age": true, "authorization": true, "content-length": true, "content-type": true,
    "etag": true, "expires": true, "from": true, "host": true,
    "if-modified-since": true, "if-unmodified-since": true, "last-modified": true,
    "location": true, "max-forwards": true, "proxy-authorization": true,
    "referer": true, "retry-after": true, "server": true, "user-agent": true
};

var _maxIdleHTTPParsers = 1000;
var _globalProxyRestore = null;
var _globalProxyEnv = null;

function findCRLF(data, from) {
    var cr = String.fromCharCode(13);
    var i = from || 0;
    while (i < data.length - 1) {
        if (data.charAt(i) === cr && data.charAt(i + 1) === "\n") {
            return i;
        }
        i = i + 1;
    }
    return -1;
}

function splitHeaderLines(headerSection) {
    var lines = [];
    var pos = 0;
    while (pos < headerSection.length) {
        var nl = findCRLF(headerSection, pos);
        if (nl === -1) {
            lines.push(headerSection.substring(pos));
            break;
        }
        lines.push(headerSection.substring(pos, nl));
        pos = nl + 2;
    }
    return lines;
}

function finalizeHeaders(rawHeaders, joinDuplicateHeaders) {
    var headers = {};
    var headersDistinct = {};
    var i = 0;
    while (i < rawHeaders.length) {
        var name = rawHeaders[i];
        var value = rawHeaders[i + 1];
        var lowerName = name.toLowerCase();
        if (headersDistinct[lowerName] === undefined) {
            headersDistinct[lowerName] = [value];
        } else {
            headersDistinct[lowerName].push(value);
        }
        if (lowerName === "set-cookie") {
            if (headers[lowerName] === undefined) {
                headers[lowerName] = value;
            } else if (Array.isArray(headers[lowerName])) {
                headers[lowerName].push(value);
            } else {
                headers[lowerName] = [headers[lowerName], value];
            }
        } else if (lowerName === "cookie") {
            if (headers[lowerName] === undefined) {
                headers[lowerName] = value;
            } else {
                headers[lowerName] = headers[lowerName] + "; " + value;
            }
        } else if (headers[lowerName] !== undefined) {
            if (joinDuplicateHeaders || !DUPLICATE_DISCARD[lowerName]) {
                headers[lowerName] = headers[lowerName] + ", " + value;
            }
        } else {
            headers[lowerName] = value;
        }
        i = i + 2;
    }
    // Node stores set-cookie as array in headers object when multiple
    var sc = headersDistinct["set-cookie"];
    if (sc && sc.length > 1) {
        headers["set-cookie"] = sc;
    } else if (sc && sc.length === 1) {
        headers["set-cookie"] = sc[0];
    }
    return { headers: headers, headersDistinct: headersDistinct };
}

function parseHeaderBlock(headerSection, joinDuplicateHeaders) {
    var lines = splitHeaderLines(headerSection);
    if (lines.length === 0) {
        return null;
    }
    var rawHeaders = [];
    var hi = 1;
    while (hi < lines.length) {
        var line = lines[hi];
        var colon = line.indexOf(":");
        if (colon > 0) {
            var name = line.substring(0, colon);
            var value = line.substring(colon + 1);
            while (value.length > 0 && value.charAt(0) === " ") {
                value = value.substring(1);
            }
            rawHeaders.push(name);
            rawHeaders.push(value);
        }
        hi = hi + 1;
    }
    return finalizeHeaders(rawHeaders, !!joinDuplicateHeaders);
}

function parseRequestHead(raw, joinDuplicateHeaders) {
    var doubleCRLF = CRLF + CRLF;
    var headerEnd = raw.indexOf(doubleCRLF);
    if (headerEnd === -1) { return null; }

    var headerSection = raw.substring(0, headerEnd);
    var bodyOffset = headerEnd + 4;
    var lines = splitHeaderLines(headerSection);
    if (lines.length === 0) { return null; }

    var requestLine = lines[0];
    var sp1 = requestLine.indexOf(" ");
    if (sp1 === -1) { return null; }
    var sp2 = requestLine.indexOf(" ", sp1 + 1);
    if (sp2 === -1) { return null; }

    var method = requestLine.substring(0, sp1);
    var url = requestLine.substring(sp1 + 1, sp2);
    var httpVersion = requestLine.substring(sp2 + 1).replace("HTTP/", "");

    var rawHeaders = [];
    var i = 1;
    while (i < lines.length) {
        var line = lines[i];
        var colon = line.indexOf(":");
        if (colon > 0) {
            var name = line.substring(0, colon);
            var value = line.substring(colon + 1);
            while (value.length > 0 && value.charAt(0) === " ") {
                value = value.substring(1);
            }
            rawHeaders.push(name);
            rawHeaders.push(value);
        }
        i = i + 1;
    }
    var fin = finalizeHeaders(rawHeaders, !!joinDuplicateHeaders);

    return {
        method: method,
        url: url,
        httpVersion: httpVersion,
        headers: fin.headers,
        headersDistinct: fin.headersDistinct,
        rawHeaders: rawHeaders,
        headerSize: bodyOffset
    };
}

function parseResponseHead(raw, joinDuplicateHeaders) {
    var doubleCRLF = CRLF + CRLF;
    var headerEnd = raw.indexOf(doubleCRLF);
    if (headerEnd === -1) { return null; }

    var headerSection = raw.substring(0, headerEnd);
    var bodyOffset = headerEnd + 4;
    var lines = splitHeaderLines(headerSection);
    if (lines.length === 0) { return null; }

    var statusLine = lines[0];
    var sp1 = statusLine.indexOf(" ");
    if (sp1 === -1) { return null; }
    var sp2 = statusLine.indexOf(" ", sp1 + 1);

    var httpVersion = statusLine.substring(0, sp1).replace("HTTP/", "");
    var statusCode, statusMessage;
    if (sp2 === -1) {
        statusCode = Number(statusLine.substring(sp1 + 1));
        statusMessage = "";
    } else {
        statusCode = Number(statusLine.substring(sp1 + 1, sp2));
        statusMessage = statusLine.substring(sp2 + 1);
    }

    var rawHeaders = [];
    var i = 1;
    while (i < lines.length) {
        var line = lines[i];
        var colon = line.indexOf(":");
        if (colon > 0) {
            var name = line.substring(0, colon);
            var value = line.substring(colon + 1);
            while (value.length > 0 && value.charAt(0) === " ") {
                value = value.substring(1);
            }
            rawHeaders.push(name);
            rawHeaders.push(value);
        }
        i = i + 1;
    }
    var fin = finalizeHeaders(rawHeaders, !!joinDuplicateHeaders);

    return {
        statusCode: statusCode,
        statusMessage: statusMessage,
        httpVersion: httpVersion,
        headers: fin.headers,
        headersDistinct: fin.headersDistinct,
        rawHeaders: rawHeaders,
        headerSize: bodyOffset
    };
}

function validateHeaderName(name, label) {
    if (typeof name !== "string" || name.length === 0) {
        var err = new TypeError("name must be a non-empty string");
        err.code = "ERR_INVALID_ARG_TYPE";
        throw err;
    }
    var i = 0;
    while (i < name.length) {
        var c = name.charCodeAt(i);
        // RFC 9110 tchar — reject controls, space, separators, and non-ASCII
        if (c > 255 || c <= 31 || c === 127 || c === 32 || c === 40 || c === 41 ||
            c === 60 || c === 62 || c === 64 || c === 44 || c === 59 || c === 58 ||
            c === 92 || c === 34 || c === 47 || c === 91 || c === 93 || c === 63 ||
            c === 61 || c === 123 || c === 125) {
            var e2 = new TypeError("Invalid character in header name");
            e2.code = "ERR_INVALID_HTTP_TOKEN";
            throw e2;
        }
        i = i + 1;
    }
}

function validateHeaderValue(name, value) {
    if (value === undefined || value === null) {
        var err = new TypeError("value must be specified");
        err.code = "ERR_HTTP_INVALID_HEADER_VALUE";
        throw err;
    }
    var str = String(value);
    var j = 0;
    while (j < str.length) {
        var ch = str.charCodeAt(j);
        // Node rejects NUL/CR/LF and any non-ASCII (charCode > 255) in values.
        if (ch === 0 || ch === 10 || ch === 13 || ch > 255) {
            var e2 = new TypeError('Invalid character in header content ["' + name + '"]');
            e2.code = "ERR_INVALID_CHAR";
            throw e2;
        }
        j = j + 1;
    }
}

function setMaxIdleHTTPParsers(max) {
    if (typeof max === "number" && max >= 0) {
        _maxIdleHTTPParsers = max;
    }
}

function getMaxIdleHTTPParsers() {
    return _maxIdleHTTPParsers;
}

function normalizeProxyEnv(proxyEnv) {
    if (!proxyEnv) { return {}; }
    return {
        HTTP_PROXY: proxyEnv.HTTP_PROXY || proxyEnv.http_proxy,
        HTTPS_PROXY: proxyEnv.HTTPS_PROXY || proxyEnv.https_proxy,
        NO_PROXY: proxyEnv.NO_PROXY || proxyEnv.no_proxy,
        http_proxy: proxyEnv.http_proxy,
        https_proxy: proxyEnv.https_proxy,
        no_proxy: proxyEnv.no_proxy
    };
}

function shouldBypassProxy(hostname, noProxy) {
    if (!noProxy) { return false; }
    if (noProxy === "*") { return true; }
    var host = (hostname || "").toLowerCase();
    var entries = noProxy.split(",");
    var i = 0;
    while (i < entries.length) {
        var pat = entries[i].trim().toLowerCase();
        if (pat.length === 0) { i = i + 1; continue; }
        if (pat.charAt(0) === ".") { pat = pat.substring(1); }
        if (pat.indexOf("*") === 0) {
            pat = pat.substring(1);
            if (host.endsWith(pat) || host === pat.substring(1)) {
                return true;
            }
        } else if (host === pat || host.endsWith("." + pat)) {
            return true;
        }
        i = i + 1;
    }
    return false;
}

function parseProxyUrl(urlStr) {
    if (!urlStr || typeof urlStr !== "string") { return null; }
    if (typeof URL !== "undefined") {
        try {
            var u = new URL(urlStr);
            var port = Number(u.port);
            if (!port) {
                port = (u.protocol === "https:") ? 443 : 80;
            }
            return {
                protocol: u.protocol,
                hostname: u.hostname,
                host: u.hostname,
                port: port
            };
        } catch (e) { /* fall through */ }
    }
    var str = urlStr;
    var proto = "http:";
    var protoEnd = str.indexOf("://");
    if (protoEnd !== -1) {
        proto = str.substring(0, protoEnd + 1);
        str = str.substring(protoEnd + 3);
    }
    var slash = str.indexOf("/");
    if (slash !== -1) { str = str.substring(0, slash); }
    var host = str;
    var port = (proto === "https:") ? 443 : 80;
    var colon = str.indexOf(":");
    if (colon !== -1) {
        host = str.substring(0, colon);
        port = Number(str.substring(colon + 1)) || port;
    }
    return { protocol: proto, hostname: host, host: host, port: port };
}

function resolveProxyUrl(isHttps, proxyEnv, hostname) {
    proxyEnv = proxyEnv || {};
    if (shouldBypassProxy(hostname, proxyEnv.NO_PROXY || proxyEnv.no_proxy)) {
        return null;
    }
    if (isHttps) {
        return proxyEnv.HTTPS_PROXY || proxyEnv.https_proxy || null;
    }
    return proxyEnv.HTTP_PROXY || proxyEnv.http_proxy || null;
}

function getProxyEnvForAgent(agent) {
    if (agent) {
        if (agent.proxyEnv === false) { return null; }
        if (agent.proxyEnv) { return agent.proxyEnv; }
    }
    if (_globalProxyEnv) { return _globalProxyEnv; }
    if (typeof process !== "undefined" && process.env) {
        return normalizeProxyEnv(process.env);
    }
    return null;
}

function isUpgradeRequest(headers) {
    if (!headers) { return false; }
    var upgrade = headers["upgrade"];
    if (!upgrade) { return false; }
    var conn = headers["connection"];
    if (!conn) { return false; }
    return conn.toLowerCase().indexOf("upgrade") !== -1;
}

function decodeChunkedSection(buf) {
    var chunks = [];
    var pos = 0;
    while (true) {
        var nl = findCRLF(buf, pos);
        if (nl === -1) { return null; }
        var sizeHex = buf.substring(pos, nl);
        var chunkSize = parseInt(sizeHex, 16);
        if (isNaN(chunkSize)) { return null; }
        if (chunkSize === 0) {
            var afterZero = nl + 2;
            if (buf.length < afterZero + 2) { return null; }
            return { body: chunks.join(""), consumed: afterZero + 2 };
        }
        var chunkStart = nl + 2;
        var chunkEnd = chunkStart + chunkSize;
        if (chunkEnd + 2 > buf.length) { return null; }
        chunks.push(buf.substring(chunkStart, chunkEnd));
        pos = chunkEnd + 2;
    }
}

function consumeIncomingBody(buffer, parsed) {
    var bodyStart = parsed.headerSize;
    var te = parsed.headers["transfer-encoding"];
    if (te && te.toLowerCase().indexOf("chunked") !== -1) {
        var chunkBuf = buffer.substring(bodyStart);
        var decoded = decodeChunkedSection(chunkBuf);
        if (decoded === null) { return null; }
        return {
            body: decoded.body,
            consumed: bodyStart + decoded.consumed
        };
    }
    var contentLength = 0;
    var cl = parsed.headers["content-length"];
    if (cl !== undefined) { contentLength = Number(cl); }
    var totalNeeded = bodyStart + contentLength;
    if (buffer.length < totalNeeded) { return null; }
    var body = "";
    if (contentLength > 0) {
        body = buffer.substring(bodyStart, totalNeeded);
    }
    return { body: body, consumed: totalNeeded };
}

function defaultPortForProtocol(protocol) {
    if (protocol === "https:") { return 443; }
    return 80;
}

function resolveRedirectLocation(location, baseProtocol, baseHost, basePort, basePath) {
    if (!location || typeof location !== "string") { return null; }
    if (location.indexOf("://") !== -1) {
        if (typeof URL !== "undefined") {
            try {
                var abs = new URL(location);
                return {
                    protocol: abs.protocol,
                    hostname: abs.hostname,
                    host: abs.hostname,
                    port: Number(abs.port) || defaultPortForProtocol(abs.protocol),
                    path: abs.pathname + (abs.search || "")
                };
            } catch (e) { /* fall through */ }
        }
    }
    if (location.charAt(0) === "/") {
        return {
            protocol: baseProtocol,
            hostname: baseHost,
            host: baseHost,
            port: basePort,
            path: location
        };
    }
    var baseDir = basePath || "/";
    var dirEnd = baseDir.lastIndexOf("/");
    var prefix = dirEnd >= 0 ? baseDir.substring(0, dirEnd + 1) : "/";
    return {
        protocol: baseProtocol,
        hostname: baseHost,
        host: baseHost,
        port: basePort,
        path: prefix + location
    };
}

function isRedirectStatus(code) {
    return code === 301 || code === 302 || code === 303 || code === 307 || code === 308;
}

function resolveClientProxy(req, connectOpts) {
    var env = getProxyEnvForAgent(req.agent);
    if (!env) { return null; }
    var targetHost = connectOpts.host || connectOpts.hostname || req.host || "localhost";
    var targetPort = Number(connectOpts.port || req.port) || (req.protocol === "https:" ? 443 : 80);
    var isHttps = req.protocol === "https:";
    var proxyUrl = resolveProxyUrl(isHttps, env, targetHost);
    if (!proxyUrl) { return null; }
    var parsed = parseProxyUrl(proxyUrl);
    if (!parsed) { return null; }
    return {
        proxyHost: parsed.hostname,
        proxyPort: parsed.port,
        targetHost: targetHost,
        targetPort: targetPort,
        isHttps: isHttps
    };
}

module.exports = {
    CRLF: CRLF,
    DUPLICATE_DISCARD: DUPLICATE_DISCARD,
    findCRLF: findCRLF,
    splitHeaderLines: splitHeaderLines,
    finalizeHeaders: finalizeHeaders,
    parseRequestHead: parseRequestHead,
    parseResponseHead: parseResponseHead,
    validateHeaderName: validateHeaderName,
    validateHeaderValue: validateHeaderValue,
    setMaxIdleHTTPParsers: setMaxIdleHTTPParsers,
    getMaxIdleHTTPParsers: getMaxIdleHTTPParsers,
    normalizeProxyEnv: normalizeProxyEnv,
    shouldBypassProxy: shouldBypassProxy,
    parseProxyUrl: parseProxyUrl,
    resolveProxyUrl: resolveProxyUrl,
    getProxyEnvForAgent: getProxyEnvForAgent,
    resolveClientProxy: resolveClientProxy,
    isUpgradeRequest: isUpgradeRequest,
    consumeIncomingBody: consumeIncomingBody,
    defaultPortForProtocol: defaultPortForProtocol,
    resolveRedirectLocation: resolveRedirectLocation,
    isRedirectStatus: isRedirectStatus,
    getGlobalProxyEnv: function() { return _globalProxyEnv; },
    setGlobalProxyEnv: function(env) { _globalProxyEnv = env; },
    getGlobalProxyRestore: function() { return _globalProxyRestore; },
    setGlobalProxyRestore: function(fn) { _globalProxyRestore = fn; }
};
