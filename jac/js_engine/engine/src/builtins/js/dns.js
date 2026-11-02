/**
 * node:dns / node:dns/promises — Node.js v24 API surface.
 * Native bridge: globalThis.__dns (OS lookup + wire DNS resolve).
 */

function _dns() {
    if (!globalThis.__dns) {
        throw new Error("dns: __dns native bridge is not available");
    }
    return globalThis.__dns;
}

function _scheduleDnsWork(work) {
    return new Promise(function (resolve, reject) {
        var run = function () {
            try {
                resolve(work());
            } catch (e) {
                reject(e);
            }
        };
        if (typeof process !== "undefined" && typeof process.nextTick === "function") {
            process.nextTick(run);
        } else if (typeof queueMicrotask === "function") {
            queueMicrotask(run);
        } else {
            setTimeout(run, 0);
        }
    });
}

function _asPromise(fn) {
    return new Promise(function (resolve, reject) {
        fn(resolve, reject);
    });
}

function _deferCallback(work, callback) {
    var run = function () {
        try {
            work(callback);
        } catch (e) {
            callback(e);
        }
    };
    if (typeof process !== "undefined" && typeof process.nextTick === "function") {
        process.nextTick(run);
    } else if (typeof queueMicrotask === "function") {
        queueMicrotask(run);
    } else {
        setTimeout(run, 0);
    }
}

function _nativeErr(obj) {
    if (!obj || !obj.code) {
        return null;
    }
    var err = new Error(obj.message || obj.code);
    err.code = obj.code;
    if (obj.errno !== undefined) {
        err.errno = obj.errno;
    }
    if (obj.syscall) {
        err.syscall = obj.syscall;
    }
    if (obj.hostname) {
        err.hostname = obj.hostname;
    }
    return err;
}

function _parseOptions(options, defaultOrder) {
    var opts = options;
    if (typeof opts === "number") {
        opts = { family: opts };
    }
    if (!opts || typeof opts !== "object") {
        opts = {};
    }
    var family = 0;
    if (opts.family === 4 || opts.family === "IPv4") {
        family = 4;
    } else if (opts.family === 6 || opts.family === "IPv6") {
        family = 6;
    }
    var hints = 0;
    if (typeof opts.hints === "number") {
        hints = opts.hints;
    }
    var order = defaultOrder || "verbatim";
    if (typeof opts.order === "string") {
        order = opts.order;
    } else if (opts.verbatim === false) {
        order = "ipv4first";
    } else if (opts.verbatim === true) {
        order = "verbatim";
    }
    return { family: family, hints: hints, order: order, all: !!opts.all };
}

function _sortEntries(entries, order) {
    if (order === "verbatim" || order === "ipv6first") {
        if (order === "verbatim") {
            return entries;
        }
        var v6f = [];
        var v4f = [];
        var j;
        for (j = 0; j < entries.length; j++) {
            if (entries[j].family === 6) {
                v6f.push(entries[j]);
            } else {
                v4f.push(entries[j]);
            }
        }
        return v6f.concat(v4f);
    }
    var v4 = [];
    var v6 = [];
    var i;
    for (i = 0; i < entries.length; i++) {
        if (entries[i].family === 6) {
            v6.push(entries[i]);
        } else {
            v4.push(entries[i]);
        }
    }
    return v4.concat(v6);
}

function _entriesFromNative(res, order) {
    if (!res || res.ok !== true) {
        throw _nativeErr(res) || new Error("dns lookup failed");
    }
    var entries = res.entries;
    if (!entries || !entries.length) {
        var e = new Error("getaddrinfo ENOTFOUND");
        e.code = "ENOTFOUND";
        e.errno = -3008;
        e.syscall = "getaddrinfo";
        throw e;
    }
    var out = [];
    var i;
    for (i = 0; i < entries.length; i++) {
        out.push({
            address: entries[i].address,
            family: entries[i].family
        });
    }
    return _sortEntries(out, order || "verbatim");
}

function _lookupCore(host, options) {
    var def = _dns().getDefaultResultOrder();
    var parsed = _parseOptions(options, def);
    var raw = _dns().lookup(host, parsed.family, parsed.hints, parsed.order);
    var entries = _entriesFromNative(raw, parsed.order);
    if (parsed.all) {
        return entries;
    }
    return entries[0];
}

function lookup(host, options, callback) {
    if (typeof options === "function") {
        callback = options;
        options = {};
    }
    if (typeof callback !== "function") {
        throw new TypeError("callback must be a function");
    }
    _deferCallback(function (cb) {
        _asPromise(function (resolve, reject) {
            try {
                resolve(_lookupCore(host, options));
            } catch (e) {
                reject(e);
            }
        }).then(
            function (result) {
                if (Array.isArray(result)) {
                    cb(null, result);
                } else {
                    cb(null, result.address, result.family);
                }
            },
            function (err) {
                cb(err);
            }
        );
    }, callback);
}

var _QTYPE = {
    A: 1,
    NS: 2,
    CNAME: 5,
    SOA: 6,
    PTR: 12,
    MX: 15,
    TXT: 16,
    AAAA: 28,
    SRV: 33,
    NAPTR: 35,
    CAA: 257
};

function _serversFor(ctx) {
    if (ctx && ctx._servers && ctx._servers.length) {
        return ctx._servers;
    }
    return undefined;
}

function _wireRaw(host, qtype, servers) {
    var raw = _dns().wireResolve(host, qtype, servers);
    if (!raw || raw.ok !== true) {
        throw _nativeErr(raw) || new Error("DNS query failed");
    }
    return raw.records || [];
}

function _wireAddresses(host, qtype, servers) {
    var recs = _wireRaw(host, qtype, servers);
    var out = [];
    var i;
    for (i = 0; i < recs.length; i++) {
        if (recs[i].address) {
            out.push(recs[i].address);
        }
    }
    return out;
}

function reverse(ip, callback) {
    if (typeof callback !== "function") {
        throw new TypeError("callback must be a function");
    }
    _deferCallback(function (cb) {
    try {
        var raw = _dns().reverse(ip, undefined);
        var names = [];
        var recs = raw && raw.records ? raw.records : raw.hostnames;
        var i;
        if (raw && raw.ok && recs) {
            for (i = 0; i < recs.length; i++) {
                if (typeof recs[i] === "string") {
                    names.push(recs[i]);
                } else if (recs[i].value) {
                    names.push(recs[i].value);
                }
            }
        } else if (raw && !raw.ok) {
            cb(_nativeErr(raw) || new Error("reverse failed"));
            return;
        }
        if (raw && raw.ok && names.length === 0) {
            var emptyErr = new Error("getHostByAddr ENOTFOUND " + ip);
            emptyErr.code = "ENOTFOUND";
            emptyErr.syscall = "queryPtr";
            cb(emptyErr);
            return;
        }
        cb(null, names);
    } catch (e) {
        cb(e);
    }
    }, callback);
}

function lookupService(address, port, callback) {
    if (typeof port === "function") {
        callback = port;
        port = 0;
    }
    if (typeof callback !== "function") {
        throw new TypeError("callback must be a function");
    }
    try {
        var raw = _dns().lookupService(address, port);
        if (!raw || !raw.ok) {
            callback(_nativeErr(raw) || new Error("lookupService failed"));
            return;
        }
        callback(null, raw.hostname, raw.service);
    } catch (e) {
        callback(e);
    }
}

function resolve4(hostname, callback, ctx) {
    if (typeof callback !== "function") {
        throw new TypeError("callback must be a function");
    }
    try {
        callback(null, _wireAddresses(hostname, _QTYPE.A, _serversFor(ctx)));
    } catch (e) {
        callback(e);
    }
}

function resolve6(hostname, callback, ctx) {
    if (typeof callback !== "function") {
        throw new TypeError("callback must be a function");
    }
    try {
        callback(null, _wireAddresses(hostname, _QTYPE.AAAA, _serversFor(ctx)));
    } catch (e) {
        callback(e);
    }
}

function resolve(hostname, rrtype, callback, ctx) {
    if (typeof rrtype === "function") {
        ctx = callback;
        callback = rrtype;
        rrtype = "A";
    }
    if (typeof callback !== "function") {
        throw new TypeError("callback must be a function");
    }
    if (rrtype === "AAAA" || rrtype === 6) {
        resolve6(hostname, callback, ctx);
        return;
    }
    if (rrtype === "A" || rrtype === 4) {
        resolve4(hostname, callback, ctx);
        return;
    }
    if (rrtype === "MX") {
        resolveMx(hostname, callback, ctx);
        return;
    }
    if (rrtype === "TXT") {
        resolveTxt(hostname, callback, ctx);
        return;
    }
    if (rrtype === "NS") {
        resolveNs(hostname, callback, ctx);
        return;
    }
    if (rrtype === "CNAME") {
        resolveCname(hostname, callback, ctx);
        return;
    }
    if (rrtype === "PTR") {
        resolvePtr(hostname, callback, ctx);
        return;
    }
    if (rrtype === "SRV") {
        resolveSrv(hostname, callback, ctx);
        return;
    }
    if (rrtype === "SOA") {
        resolveSoa(hostname, callback, ctx);
        return;
    }
    if (rrtype === "NAPTR") {
        resolveNaptr(hostname, callback, ctx);
        return;
    }
    if (rrtype === "CAA") {
        resolveCaa(hostname, callback, ctx);
        return;
    }
    var err = new Error("queryA ENOTIMP");
    err.code = "ENOTIMP";
    callback(err);
}

function resolveAny(hostname, callback, ctx) {
    if (typeof callback !== "function") {
        throw new TypeError("callback must be a function");
    }
    try {
        var v4 = _wireAddresses(hostname, _QTYPE.A, _serversFor(ctx));
        var v6 = [];
        try {
            v6 = _wireAddresses(hostname, _QTYPE.AAAA, _serversFor(ctx));
        } catch (e6) {
            /* ignore */
        }
        var out = [];
        var i;
        for (i = 0; i < v4.length; i++) {
            out.push({ type: "A", address: v4[i] });
        }
        for (i = 0; i < v6.length; i++) {
            out.push({ type: "AAAA", address: v6[i] });
        }
        callback(null, out);
    } catch (e) {
        callback(e);
    }
}

function resolveCname(hostname, callback, ctx) {
    if (typeof callback !== "function") {
        throw new TypeError("callback must be a function");
    }
    try {
        var recs = _wireRaw(hostname, _QTYPE.CNAME, _serversFor(ctx));
        var out = [];
        var i;
        for (i = 0; i < recs.length; i++) {
            if (recs[i].value) {
                out.push(recs[i].value);
            }
        }
        callback(null, out);
    } catch (e) {
        callback(e);
    }
}

function resolveMx(hostname, callback, ctx) {
    if (typeof callback !== "function") {
        throw new TypeError("callback must be a function");
    }
    try {
        var recs = _wireRaw(hostname, _QTYPE.MX, _serversFor(ctx));
        var out = [];
        var i;
        for (i = 0; i < recs.length; i++) {
            out.push({
                priority: recs[i].priority || 0,
                exchange: recs[i].exchange || ""
            });
        }
        callback(null, out);
    } catch (e) {
        callback(e);
    }
}

function resolveNs(hostname, callback, ctx) {
    if (typeof callback !== "function") {
        throw new TypeError("callback must be a function");
    }
    try {
        var recs = _wireRaw(hostname, _QTYPE.NS, _serversFor(ctx));
        var out = [];
        var i;
        for (i = 0; i < recs.length; i++) {
            if (recs[i].value) {
                out.push(recs[i].value);
            }
        }
        callback(null, out);
    } catch (e) {
        callback(e);
    }
}

function resolvePtr(hostname, callback, ctx) {
    if (typeof callback !== "function") {
        throw new TypeError("callback must be a function");
    }
    try {
        var recs = _wireRaw(hostname, _QTYPE.PTR, _serversFor(ctx));
        var out = [];
        var i;
        for (i = 0; i < recs.length; i++) {
            if (recs[i].value) {
                out.push(recs[i].value);
            }
        }
        callback(null, out);
    } catch (e) {
        callback(e);
    }
}

function resolveSrv(hostname, callback, ctx) {
    if (typeof callback !== "function") {
        throw new TypeError("callback must be a function");
    }
    try {
        var recs = _wireRaw(hostname, _QTYPE.SRV, _serversFor(ctx));
        var out = [];
        var i;
        for (i = 0; i < recs.length; i++) {
            out.push({
                priority: recs[i].priority || 0,
                weight: recs[i].weight || 0,
                port: recs[i].port || 0,
                name: recs[i].name || ""
            });
        }
        callback(null, out);
    } catch (e) {
        callback(e);
    }
}

function resolveTxt(hostname, callback, ctx) {
    if (typeof callback !== "function") {
        throw new TypeError("callback must be a function");
    }
    try {
        var recs = _wireRaw(hostname, _QTYPE.TXT, _serversFor(ctx));
        var out = [];
        var i;
        for (i = 0; i < recs.length; i++) {
            if (recs[i].value !== undefined) {
                out.push([recs[i].value]);
            }
        }
        callback(null, out);
    } catch (e) {
        callback(e);
    }
}

function resolveSoa(hostname, callback, ctx) {
    if (typeof callback !== "function") {
        throw new TypeError("callback must be a function");
    }
    try {
        var recs = _wireRaw(hostname, _QTYPE.SOA, _serversFor(ctx));
        if (!recs.length) {
            throw Object.assign(new Error("querySoa ENODATA"), { code: "ENODATA" });
        }
        var r = recs[0];
        callback(null, {
            nsname: r.nsname,
            hostmaster: r.hostmaster,
            serial: r.serial,
            refresh: r.refresh,
            retry: r.retry,
            expire: r.expire,
            minttl: r.minttl
        });
    } catch (e) {
        callback(e);
    }
}

function resolveNaptr(hostname, callback, ctx) {
    if (typeof callback !== "function") {
        throw new TypeError("callback must be a function");
    }
    try {
        var recs = _wireRaw(hostname, _QTYPE.NAPTR, _serversFor(ctx));
        var out = [];
        var i;
        for (i = 0; i < recs.length; i++) {
            out.push({
                flags: recs[i].flags || "",
                order: recs[i].order || 0,
                preference: recs[i].preference || 0,
                services: recs[i].services || "",
                regexp: recs[i].regexp || "",
                replacement: recs[i].replacement || ""
            });
        }
        callback(null, out);
    } catch (e) {
        callback(e);
    }
}

function resolveCaa(hostname, callback, ctx) {
    if (typeof callback !== "function") {
        throw new TypeError("callback must be a function");
    }
    try {
        var recs = _wireRaw(hostname, _QTYPE.CAA, _serversFor(ctx));
        var out = [];
        var i;
        for (i = 0; i < recs.length; i++) {
            var entry = {
                critical: !!recs[i].critical,
                issue: recs[i].issue || "",
                value: recs[i].value || ""
            };
            out.push(entry);
        }
        callback(null, out);
    } catch (e) {
        callback(e);
    }
}

function getDefaultResultOrder() {
    return _dns().getDefaultResultOrder();
}

function setDefaultResultOrder(order) {
    _dns().setDefaultResultOrder(order);
}

function getServers() {
    return _dns().getServers();
}

function setServers(servers) {
    var raw = _dns().setServers(servers);
    if (raw && raw.code) {
        var err = new Error(
            raw.code === "ERR_DNS_SET_SERVERS_FAILED"
                ? "There are pending queries registered on the resolver"
                : raw.code
        );
        err.code = raw.code;
        throw err;
    }
}

function promisify(fn) {
    return function () {
        var args = Array.prototype.slice.call(arguments);
        return new Promise(function (resolve, reject) {
            args.push(function (err, result) {
                if (err) {
                    reject(err);
                } else {
                    resolve(result);
                }
            });
            fn.apply(null, args);
        });
    };
}

var promises = {
    lookup: function (host, options) {
        return _scheduleDnsWork(function () {
            return _lookupCore(host, options);
        });
    },
    reverse: function (ip) {
        return _asPromise(function (resolve, reject) {
            reverse(ip, function (err, names) {
                if (err) {
                    reject(err);
                } else {
                    resolve(names);
                }
            });
        });
    },
    lookupService: function (address, port) {
        return _asPromise(function (resolve, reject) {
            lookupService(address, port, function (err, hostname, service) {
                if (err) {
                    reject(err);
                } else {
                    resolve({ hostname: hostname, service: service });
                }
            });
        });
    },
    resolve: promisify(resolve),
    resolve4: promisify(resolve4),
    resolve6: promisify(resolve6),
    resolveAny: promisify(resolveAny),
    resolveCname: promisify(resolveCname),
    resolveMx: promisify(resolveMx),
    resolveNs: promisify(resolveNs),
    resolvePtr: promisify(resolvePtr),
    resolveSrv: promisify(resolveSrv),
    resolveTxt: promisify(resolveTxt),
    resolveSoa: promisify(resolveSoa),
    resolveNaptr: promisify(resolveNaptr),
    resolveCaa: promisify(resolveCaa),
    getDefaultResultOrder: getDefaultResultOrder,
    setDefaultResultOrder: setDefaultResultOrder,
    getServers: getServers,
    setServers: setServers,
    Resolver: function Resolver() {
        this._servers = null;
    }
};

function _resolverMethod(fn) {
    return function () {
        var args = Array.prototype.slice.call(arguments);
        var self = this;
        return new Promise(function (resolve, reject) {
            args.push(function (err, result) {
                if (err) {
                    reject(err);
                } else {
                    resolve(result);
                }
            });
            fn.apply(self, args);
        });
    };
}

promises.Resolver.prototype.resolve4 = _resolverMethod(function (hostname, cb) {
    resolve4(hostname, cb, this);
});
promises.Resolver.prototype.resolve6 = _resolverMethod(function (hostname, cb) {
    resolve6(hostname, cb, this);
});
promises.Resolver.prototype.resolve = _resolverMethod(function (hostname, rrtype, cb) {
    resolve(hostname, rrtype, cb, this);
});
promises.Resolver.prototype.reverse = _resolverMethod(function (ip, cb) {
    var self = this;
    try {
        var raw = _dns().reverse(ip, _serversFor(self));
        var names = [];
        var recs = raw && raw.records ? raw.records : [];
        var i;
        if (raw && raw.ok) {
            for (i = 0; i < recs.length; i++) {
                if (recs[i].value) {
                    names.push(recs[i].value);
                }
            }
            cb(null, names);
        } else {
            cb(_nativeErr(raw) || new Error("reverse failed"));
        }
    } catch (e) {
        cb(e);
    }
});
promises.Resolver.prototype.getServers = function () {
    return this._servers || getServers();
};
promises.Resolver.prototype.setServers = function (servers) {
    this._servers = servers.slice();
};
// Node Resolver.cancel is not yet implemented (no in-flight query registry).
promises.Resolver.prototype.cancel = function () {};

promises.Resolver.prototype.resolveAny = _resolverMethod(function (hostname, cb) {
    resolveAny(hostname, cb, this);
});
promises.Resolver.prototype.resolveCname = _resolverMethod(function (hostname, cb) {
    resolveCname(hostname, cb, this);
});
promises.Resolver.prototype.resolveMx = _resolverMethod(function (hostname, cb) {
    resolveMx(hostname, cb, this);
});
promises.Resolver.prototype.resolveNs = _resolverMethod(function (hostname, cb) {
    resolveNs(hostname, cb, this);
});
promises.Resolver.prototype.resolvePtr = _resolverMethod(function (hostname, cb) {
    resolvePtr(hostname, cb, this);
});
promises.Resolver.prototype.resolveSrv = _resolverMethod(function (hostname, cb) {
    resolveSrv(hostname, cb, this);
});
promises.Resolver.prototype.resolveTxt = _resolverMethod(function (hostname, cb) {
    resolveTxt(hostname, cb, this);
});
promises.Resolver.prototype.resolveSoa = _resolverMethod(function (hostname, cb) {
    resolveSoa(hostname, cb, this);
});
promises.Resolver.prototype.resolveNaptr = _resolverMethod(function (hostname, cb) {
    resolveNaptr(hostname, cb, this);
});
promises.Resolver.prototype.resolveCaa = _resolverMethod(function (hostname, cb) {
    resolveCaa(hostname, cb, this);
});

function Resolver() {
    return new promises.Resolver();
}

Resolver.prototype = promises.Resolver.prototype;

var dns = {
    lookup: lookup,
    lookupService: lookupService,
    resolve: resolve,
    resolve4: resolve4,
    resolve6: resolve6,
    resolveAny: resolveAny,
    resolveCname: resolveCname,
    resolveMx: resolveMx,
    resolveNs: resolveNs,
    resolvePtr: resolvePtr,
    resolveSrv: resolveSrv,
    resolveTxt: resolveTxt,
    resolveSoa: resolveSoa,
    resolveNaptr: resolveNaptr,
    resolveCaa: resolveCaa,
    reverse: reverse,
    getDefaultResultOrder: getDefaultResultOrder,
    setDefaultResultOrder: setDefaultResultOrder,
    getServers: getServers,
    setServers: setServers,
    promises: promises,
    Resolver: Resolver,
    ADDRCONFIG: 32,
    V4MAPPED: 2048,
    ALL: 256,
    NODATA: "ENODATA",
    FORMERR: "EFORMERR",
    SERVFAIL: "ESERVFAIL",
    NOTFOUND: "ENOTFOUND",
    NOTIMP: "ENOTIMP",
    REFUSED: "EREFUSED",
    BADQUERY: "EBADQUERY",
    BADNAME: "EBADNAME",
    BADFAMILY: "EBADFAMILY",
    BADRESP: "EBADRESP",
    CONNREFUSED: "ECONNREFUSED",
    TIMEOUT: "ETIMEOUT",
    EOF: "EOF",
    FILE: "EFILE",
    NOMEM: "ENOMEM",
    DESTRUCTION: "EDESTRUCTION",
    BADSTR: "EBADSTR",
    BADFLAGS: "EBADFLAGS",
    NONAME: "ENONAME",
    BADHINTS: "EBADHINTS",
    NOTINITIALIZED: "ENOTINITIALIZED",
    LOADIPHLPAPI: "ELOADIPHLPAPI",
    ADDRGETNETWORKPARAMS: "EADDRGETNETWORKPARAMS",
    CANCELLED: "ECANCELLED"
};

module.exports = dns;
