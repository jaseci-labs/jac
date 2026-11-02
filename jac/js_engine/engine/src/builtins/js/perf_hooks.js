/**
 * perf_hooks.js — Node.js `perf_hooks` / `node:perf_hooks` (v22 LTS parity)
 *
 * Pure JS implementation; `performance.now()` delegates to the engine native clock
 * when `globalThis.performance.now` exists (installed before bootstrap).
 */

// ── GC constants (match Node v22) ─────────────────────────────────────────
var constants = {
    NODE_PERFORMANCE_GC_MAJOR: 4,
    NODE_PERFORMANCE_GC_MINOR: 1,
    NODE_PERFORMANCE_GC_INCREMENTAL: 8,
    NODE_PERFORMANCE_GC_WEAKCB: 16,
    NODE_PERFORMANCE_GC_FLAGS_NO: 0,
    NODE_PERFORMANCE_GC_FLAGS_CONSTRUCT_RETAINED: 2,
    NODE_PERFORMANCE_GC_FLAGS_FORCED: 4,
    NODE_PERFORMANCE_GC_FLAGS_SYNCHRONOUS_PHANTOM_PROCESSING: 8,
    NODE_PERFORMANCE_GC_FLAGS_ALL_AVAILABLE_GARBAGE: 16,
    NODE_PERFORMANCE_GC_FLAGS_ALL_EXTERNAL_MEMORY: 32,
    NODE_PERFORMANCE_GC_FLAGS_SCHEDULE_IDLE: 64
};

var SUPPORTED_ENTRY_TYPES = [
    "dns", "function", "gc", "http", "http2", "mark", "measure", "net", "resource"
];

// ── Monotonic clock ─────────────────────────────────────────────────────────
var _nativeNow =
    typeof performance !== "undefined" && typeof performance.now === "function"
        ? performance.now.bind(performance)
        : function () {
              return Date.now();
          };

var _timeOrigin = Date.now() - _nativeNow();

function now() {
    return _nativeNow();
}

// ── Timeline store (globalThis — module lexical state is not reliable in js_engine)
function _state() {
    if (typeof globalThis !== "undefined" && globalThis.__nodePerfHooksState) {
        return globalThis.__nodePerfHooksState;
    }
    var s = {
        entries: [],
        resourceEntries: [],
        resourceBufferSize: 250,
        resourceBufferFull: false,
        observers: []
    };
    if (typeof globalThis !== "undefined") {
        globalThis.__nodePerfHooksState = s;
    }
    return s;
}

function _entries() {
    return _state().entries;
}

function _resourceEntries() {
    return _state().resourceEntries;
}

function _makeEntry(name, entryType, startTime, duration, detail) {
    var e = {
        name: String(name),
        entryType: entryType,
        startTime: startTime,
        duration: duration,
        detail: detail === undefined ? null : detail
    };
    e.toJSON = function () {
        var o = {
            name: e.name,
            entryType: e.entryType,
            startTime: e.startTime,
            duration: e.duration
        };
        if (e.detail !== null && e.detail !== undefined) {
            o.detail = e.detail;
        }
        return o;
    };
    return e;
}

function _sortByStartTime(list) {
    return list.slice().sort(function (a, b) {
        if (a.startTime !== b.startTime) {
            return a.startTime - b.startTime;
        }
        return 0;
    });
}

function _notifyObservers(entry) {
    var obsList = _state().observers;
    var i = 0;
    while (i < obsList.length) {
        var obs = obsList[i];
        if (!obs._connected) {
            i = i + 1;
            continue;
        }
        if (obs._types.indexOf(entry.entryType) >= 0) {
            obs._pending.push(entry);
            obs._scheduleNotify();
        }
        i = i + 1;
    }
}

function _addEntry(entry) {
    _entries().push(entry);
    _notifyObservers(entry);
}

function _addResourceEntry(entry) {
    var st = _state();
    if (_resourceEntries().length >= st.resourceBufferSize) {
        if (!st.resourceBufferFull) {
            st.resourceBufferFull = true;
            if (typeof _performanceEmitter !== "undefined") {
                _performanceEmitter.emit("resourcetimingbufferfull");
            }
        }
        return;
    }
    _resourceEntries().push(entry);
    _entries().push(entry);
    _notifyObservers(entry);
}

// ── Performance object ─────────────────────────────────────────────────────
var _performanceEmitter = null;

function _getMarkByName(name) {
    var list = _entries();
    var i = list.length - 1;
    while (i >= 0) {
        var e = list[i];
        if (e.entryType === "mark" && e.name === name) {
            return e;
        }
        i = i - 1;
    }
    return null;
}

function _resolveTime(markOrTime) {
    if (typeof markOrTime === "number") {
        return markOrTime;
    }
    if (typeof markOrTime === "string") {
        var m = _getMarkByName(markOrTime);
        if (m !== null) {
            return m.startTime;
        }
        if (_nodeTiming && typeof _nodeTiming[markOrTime] === "number") {
            var v = _nodeTiming[markOrTime];
            if (v >= 0) {
                return v;
            }
        }
        var err = new Error(
            "Failed to execute 'measure' on 'Performance': The mark '" +
                markOrTime +
                "' does not exist."
        );
        err.name = "SyntaxError";
        throw err;
    }
    return now();
}

var _nodeTiming = {
    name: "node",
    entryType: "node",
    startTime: 0,
    duration: 0,
    nodeStart: 0,
    v8Start: 0,
    environment: 0,
    bootstrapComplete: -1,
    loopStart: -1,
    loopExit: -1,
    idleTime: 0
};

_nodeTiming.nodeStart = now();
_nodeTiming.v8Start = now();
_nodeTiming.environment = now();

function mark(name, options) {
    if (arguments.length < 1) {
        throw new TypeError("Failed to execute 'mark' on 'Performance': 1 argument required, but only 0 present.");
    }
    var n = String(name);
    var st = now();
    var detail = null;
    if (options !== undefined && options !== null) {
        if (typeof options !== "object") {
            throw new TypeError("Failed to execute 'mark' on 'Performance': parameter 2 is not of type 'Object'.");
        }
        if (options.startTime !== undefined) {
            st = Number(options.startTime);
        }
        if (options.detail !== undefined) {
            detail = options.detail;
        }
    }
    var entry = _makeEntry(n, "mark", st, 0, detail);
    _addEntry(entry);
    return entry;
}

function measure(name, startMarkOrOptions, endMark) {
    if (arguments.length < 1) {
        throw new TypeError("Failed to execute 'measure' on 'Performance': 1 argument required, but only 0 present.");
    }
    var n = String(name);
    var startTime;
    var endTime;
    var detail = null;

    if (typeof startMarkOrOptions === "object" && startMarkOrOptions !== null && endMark === undefined) {
        var opts = startMarkOrOptions;
        if (opts.detail !== undefined) {
            detail = opts.detail;
        }
        if (opts.duration !== undefined) {
            var dur = Number(opts.duration);
            endTime = now();
            startTime = endTime - dur;
        } else {
            if (opts.start !== undefined) {
                startTime = _resolveTime(opts.start);
            } else {
                startTime = 0;
            }
            if (opts.end !== undefined) {
                endTime = _resolveTime(opts.end);
            } else {
                endTime = now();
            }
        }
    } else {
        if (startMarkOrOptions !== undefined) {
            startTime = _resolveTime(startMarkOrOptions);
        } else {
            startTime = 0;
        }
        if (endMark !== undefined) {
            endTime = _resolveTime(endMark);
        } else {
            endTime = now();
        }
    }

    var duration = endTime - startTime;
    if (duration < 0) {
        duration = 0;
    }
    var entry = _makeEntry(n, "measure", startTime, duration, detail);
    _addEntry(entry);
    return entry;
}

function clearMarks(name) {
    var list = _entries();
    var i = 0;
    var out = [];
    while (i < list.length) {
        var e = list[i];
        if (e.entryType === "mark" && (name === undefined || e.name === String(name))) {
            i = i + 1;
            continue;
        }
        out.push(e);
        i = i + 1;
    }
    _state().entries = out;
}

function clearMeasures(name) {
    var list = _entries();
    var i = 0;
    var out = [];
    while (i < list.length) {
        var e = list[i];
        if (e.entryType === "measure" && (name === undefined || e.name === String(name))) {
            i = i + 1;
            continue;
        }
        out.push(e);
        i = i + 1;
    }
    _state().entries = out;
}

function clearResourceTimings(name) {
    var st = _state();
    var i = 0;
    var outR = [];
    while (i < _resourceEntries().length) {
        var e = _resourceEntries()[i];
        if (name === undefined || e.name === String(name)) {
            i = i + 1;
            continue;
        }
        outR.push(e);
        i = i + 1;
    }
    st.resourceEntries = outR;
    st.resourceBufferFull = false;
    var list = _entries();
    i = 0;
    var outE = [];
    while (i < list.length) {
        var e2 = list[i];
        if (e2.entryType !== "resource" || (name !== undefined && e2.name !== String(name))) {
            outE.push(e2);
        }
        i = i + 1;
    }
    st.entries = outE;
}

function getEntries() {
    return _sortByStartTime(_entries());
}

function getEntriesByName(name, type) {
    var n = String(name);
    var out = [];
    var list = _entries();
    var i = 0;
    while (i < list.length) {
        var e = list[i];
        if (e.name === n && (type === undefined || e.entryType === type)) {
            out.push(e);
        }
        i = i + 1;
    }
    return _sortByStartTime(out);
}

function getEntriesByType(type) {
    var out = [];
    var list = _entries();
    var i = 0;
    while (i < list.length) {
        if (list[i].entryType === type) {
            out.push(list[i]);
        }
        i = i + 1;
    }
    return _sortByStartTime(out);
}

function setResourceTimingBufferSize(maxSize) {
    var m = Number(maxSize);
    if (m !== m || m < 0) {
        throw new RangeError("The maximum size must be a positive number");
    }
    _state().resourceBufferSize = m | 0;
}

function markResourceTiming(timingInfo, requestedUrl, initiatorType, global, cacheMode, bodyInfo, responseStatus, deliveryType) {
    var url = String(requestedUrl);
    var st = now();
    var entry = _makeEntry(url, "resource", st, 0, null);
    entry.initiatorType = String(initiatorType);
    entry.workerStart = 0;
    entry.redirectStart = 0;
    entry.redirectEnd = 0;
    entry.fetchStart = st;
    entry.domainLookupStart = st;
    entry.domainLookupEnd = st;
    entry.connectStart = st;
    entry.connectEnd = st;
    entry.secureConnectionStart = 0;
    entry.requestStart = st;
    entry.responseEnd = st;
    entry.transferSize = 0;
    entry.encodedBodySize = 0;
    entry.decodedBodySize = 0;
    if (timingInfo && typeof timingInfo === "object") {
        var keys = ["fetchStart", "domainLookupStart", "domainLookupEnd", "connectStart", "connectEnd", "requestStart", "responseEnd"];
        var ki = 0;
        while (ki < keys.length) {
            var k = keys[ki];
            if (timingInfo[k] !== undefined) {
                entry[k] = Number(timingInfo[k]);
            }
            ki = ki + 1;
        }
        if (timingInfo.transferSize !== undefined) {
            entry.transferSize = Number(timingInfo.transferSize);
        }
    }
    _addResourceEntry(entry);
    return entry;
}

// Event loop utilization (sampler-based parity)
var _eluState = { idle: 0, active: 0, utilization: 0 };
var _eluLastCheck = now();
var _eluInCallback = false;

function _eluTick() {
    if (_eluInCallback) {
        return;
    }
    _eluInCallback = true;
    var t = now();
    var delta = t - _eluLastCheck;
    _eluLastCheck = t;
    _eluState.active = _eluState.active + delta;
    setImmediate(function () {
        var t2 = now();
        var idleDelta = t2 - t;
        _eluState.idle = _eluState.idle + idleDelta;
        _eluLastCheck = t2;
        var total = _eluState.idle + _eluState.active;
        _eluState.utilization = total > 0 ? _eluState.active / total : 0;
        _eluInCallback = false;
        _eluTick();
    });
}
var _eluStarted = false;

function _ensureEluSampler() {
    if (_eluStarted) {
        return;
    }
    _eluStarted = true;
    if (typeof setImmediate === "function") {
        _eluTick();
    }
}

function eventLoopUtilization(utilization1, utilization2) {
    _ensureEluSampler();
    if (utilization1 === undefined) {
        return {
            idle: _eluState.idle,
            active: _eluState.active,
            utilization: _eluState.utilization
        };
    }
    if (utilization2 !== undefined) {
        var idle = utilization2.idle - utilization1.idle;
        var active = utilization2.active - utilization1.active;
        var total = idle + active;
        return {
            idle: idle,
            active: active,
            utilization: total > 0 ? active / total : 0
        };
    }
    var idleD = _eluState.idle - utilization1.idle;
    var activeD = _eluState.active - utilization1.active;
    var tot = idleD + activeD;
    return {
        idle: idleD,
        active: activeD,
        utilization: tot > 0 ? activeD / tot : 0
    };
}

function timerify(fn, options) {
    if (typeof fn !== "function") {
        throw new TypeError("The \"fn\" argument must be of type function.");
    }
    var histogram = options && options.histogram ? options.histogram : null;
    var name = fn.name || "anonymous";

    function wrapped() {
        var args = [];
        var ai = 0;
        while (ai < arguments.length) {
            args.push(arguments[ai]);
            ai = ai + 1;
        }
        var start = now();
        var result;
        try {
            result = fn.apply(this, args);
        } catch (ex) {
            var endErr = now();
            _emitFunctionEntry(name, start, endErr - start, args);
            throw ex;
        }
        if (result !== null && typeof result === "object" && typeof result.then === "function") {
            return result.then(
                function (val) {
                    var endOk = now();
                    _emitFunctionEntry(name, start, endOk - start, args);
                    if (histogram) {
                        histogram.record(Math.floor((endOk - start) * 1e6));
                    }
                    return val;
                },
                function (err) {
                    var endFail = now();
                    _emitFunctionEntry(name, start, endFail - start, args);
                    if (histogram) {
                        histogram.record(Math.floor((endFail - start) * 1e6));
                    }
                    throw err;
                }
            );
        }
        var end = now();
        _emitFunctionEntry(name, start, end - start, args);
        if (histogram) {
            histogram.record(Math.floor((end - start) * 1e6));
        }
        return result;
    }
    return wrapped;
}

function _emitFunctionEntry(name, startTime, duration, args) {
    var entry = _makeEntry(name, "function", startTime, duration, args);
    _addEntry(entry);
}

function toJSON() {
    return {
        timeOrigin: _timeOrigin,
        timing: _nodeTiming
    };
}

// Performance event target (resourcetimingbufferfull)
var _perfListeners = {};

var performance = {
    now: now,
    timeOrigin: _timeOrigin,
    nodeTiming: _nodeTiming,
    mark: mark,
    measure: measure,
    clearMarks: clearMarks,
    clearMeasures: clearMeasures,
    clearResourceTimings: clearResourceTimings,
    getEntries: getEntries,
    getEntriesByName: getEntriesByName,
    getEntriesByType: getEntriesByType,
    setResourceTimingBufferSize: setResourceTimingBufferSize,
    markResourceTiming: markResourceTiming,
    eventLoopUtilization: eventLoopUtilization,
    timerify: timerify,
    toJSON: toJSON,
    addEventListener: function (type, listener) {
        if (!_perfListeners[type]) {
            _perfListeners[type] = [];
        }
        _perfListeners[type].push(listener);
    },
    removeEventListener: function (type, listener) {
        if (!_perfListeners[type]) {
            return;
        }
        var list = _perfListeners[type];
        var i = list.length - 1;
        while (i >= 0) {
            if (list[i] === listener) {
                list.splice(i, 1);
            }
            i = i - 1;
        }
    }
};

_performanceEmitter = {
    emit: function (type) {
        var list = _perfListeners[type];
        if (!list) {
            return;
        }
        var i = 0;
        while (i < list.length) {
            try {
                list[i]({ type: type });
            } catch (e) {}
            i = i + 1;
        }
    }
};

// Mark bootstrap complete on first tick
if (typeof setImmediate === "function") {
    setImmediate(function () {
        if (_nodeTiming.bootstrapComplete < 0) {
            _nodeTiming.bootstrapComplete = now();
            _nodeTiming.loopStart = now();
        }
    });
}

// ── Histogram ─────────────────────────────────────────────────────────────
function _validatePercentile(p) {
    if (typeof p !== "number" || p <= 0 || p > 100) {
        throw new RangeError("percentile must be between 0 and 100");
    }
}

function _computeStats(samples) {
    if (samples.length === 0) {
        return { count: 0, min: 0, max: 0, mean: 0, stddev: 0, exceeds: 0 };
    }
    var min = samples[0];
    var max = samples[0];
    var sum = 0;
    var i = 0;
    while (i < samples.length) {
        var v = samples[i];
        if (v < min) {
            min = v;
        }
        if (v > max) {
            max = v;
        }
        sum = sum + v;
        i = i + 1;
    }
    var mean = sum / samples.length;
    var varSum = 0;
    i = 0;
    while (i < samples.length) {
        var d = samples[i] - mean;
        varSum = varSum + d * d;
        i = i + 1;
    }
    var stddev = Math.sqrt(varSum / samples.length);
    var exceeds = 0;
    var threshold = 3600 * 1e9;
    i = 0;
    while (i < samples.length) {
        if (samples[i] > threshold) {
            exceeds = exceeds + 1;
        }
        i = i + 1;
    }
    return { count: samples.length, min: min, max: max, mean: mean, stddev: stddev, exceeds: exceeds };
}

function _percentileFromSorted(sorted, p) {
    if (sorted.length === 0) {
        return 0;
    }
    var idx = Math.ceil((p / 100) * sorted.length) - 1;
    if (idx < 0) {
        idx = 0;
    }
    if (idx >= sorted.length) {
        idx = sorted.length - 1;
    }
    return sorted[idx];
}

function createHistogram(options) {
    options = options || {};
    var lowest = options.lowest !== undefined ? Number(options.lowest) : 1;
    var highest =
        options.highest !== undefined ? Number(options.highest) : Number.MAX_SAFE_INTEGER;
    var figures = options.figures !== undefined ? Number(options.figures) : 3;
    if (lowest <= 0 || lowest !== Math.floor(lowest)) {
        throw new RangeError("hist.lowest must be a positive integer");
    }
    if (highest < lowest * 2) {
        throw new RangeError("hist.highest must be >= 2 * hist.lowest");
    }
    if (figures < 1 || figures > 5) {
        throw new RangeError("hist.figures must be between 1 and 5");
    }

  var samples = [];
  var lastRecord = null;

  var hist = {
    _samples: samples,
    _lowest: lowest,
    _highest: highest,
    get count() {
      return samples.length;
    },
    get countBigInt() {
      return BigInt(samples.length);
    },
    get exceeds() {
      return _computeStats(samples).exceeds;
    },
    get exceedsBigInt() {
      return BigInt(_computeStats(samples).exceeds);
    },
    get min() {
      return _computeStats(samples).min;
    },
    get minBigInt() {
      return BigInt(Math.floor(_computeStats(samples).min));
    },
    get max() {
      return _computeStats(samples).max;
    },
    get maxBigInt() {
      return BigInt(Math.floor(_computeStats(samples).max));
    },
    get mean() {
      return _computeStats(samples).mean;
    },
    get stddev() {
      return _computeStats(samples).stddev;
    },
    get percentiles() {
      var sorted = samples.slice().sort(function (a, b) {
        return a - b;
      });
      var m = new Map();
      var ps = [50, 90, 99];
      var pi = 0;
      while (pi < ps.length) {
        m.set(ps[pi], _percentileFromSorted(sorted, ps[pi]));
        pi = pi + 1;
      }
      return m;
    },
    get percentilesBigInt() {
      var sorted = samples.slice().sort(function (a, b) {
        return a - b;
      });
      var m = new Map();
      var ps = [50, 90, 99];
      var pi = 0;
      while (pi < ps.length) {
        m.set(ps[pi], BigInt(Math.floor(_percentileFromSorted(sorted, ps[pi]))));
        pi = pi + 1;
      }
      return m;
    },
    percentile: function (p) {
      _validatePercentile(p);
      var sorted = samples.slice().sort(function (a, b) {
        return a - b;
      });
      return _percentileFromSorted(sorted, p);
    },
    percentileBigInt: function (p) {
      _validatePercentile(p);
      return BigInt(Math.floor(hist.percentile(p)));
    },
    reset: function () {
      samples.length = 0;
      lastRecord = null;
    },
    record: function (val) {
      var v = Number(val);
      if (v < lowest) {
        v = lowest;
      }
      if (v > highest) {
        v = highest;
      }
      samples.push(v);
    },
    recordDelta: function () {
      var t = typeof process !== "undefined" && process.hrtime ? process.hrtime() : null;
      var ns;
      if (t) {
        ns = t[0] * 1e9 + t[1];
      } else {
        ns = Math.floor(now() * 1e6);
      }
      if (lastRecord === null) {
        lastRecord = ns;
        return;
      }
      hist.record(ns - lastRecord);
      lastRecord = ns;
    },
    add: function (other) {
      if (!other || !other._samples) {
        throw new TypeError("other must be a RecordableHistogram");
      }
      var j = 0;
      while (j < other._samples.length) {
        samples.push(other._samples[j]);
        j = j + 1;
      }
    }
  };
  return hist;
}

function monitorEventLoopDelay(options) {
  options = options || {};
  var resolution = options.resolution !== undefined ? Number(options.resolution) : 10;
  if (resolution <= 0) {
    throw new RangeError("resolution must be greater than 0");
  }
  var hist = createHistogram({ lowest: 1, highest: Number.MAX_SAFE_INTEGER, figures: 3 });
  var timerId = null;
  var expected = 0;

  hist.enable = function () {
    if (timerId !== null) {
      return false;
    }
    expected = now() + resolution;
    timerId = setInterval(function () {
      var actual = now();
      var delayNs = Math.max(0, (actual - expected) * 1e6);
      hist.record(delayNs);
      expected = actual + resolution;
    }, resolution);
    return true;
  };
  hist.disable = function () {
    if (timerId === null) {
      return false;
    }
    clearInterval(timerId);
    timerId = null;
    return true;
  };
  return hist;
}

// ── PerformanceObserver ─────────────────────────────────────────────────────

class PerformanceObserverEntryList {
  constructor(entries) {
    this._entries = entries.slice();
  }
  getEntries() {
    return _sortByStartTime(this._entries);
  }
  getEntriesByName(name, type) {
    var n = String(name);
    var out = [];
    var i = 0;
    while (i < this._entries.length) {
      var e = this._entries[i];
      if (e.name === n && (type === undefined || e.entryType === type)) {
        out.push(e);
      }
      i = i + 1;
    }
    return _sortByStartTime(out);
  }
  getEntriesByType(type) {
    var out = [];
    var i = 0;
    while (i < this._entries.length) {
      if (this._entries[i].entryType === type) {
        out.push(this._entries[i]);
      }
      i = i + 1;
    }
    return _sortByStartTime(out);
  }
}

class PerformanceObserver {
  constructor(callback) {
    if (typeof callback !== "function") {
      throw new TypeError("callback must be a function");
    }
    this._callback = callback;
    this._connected = false;
    this._types = [];
    this._buffered = false;
    this._pending = [];
    this._notifyScheduled = false;
    _state().observers.push(this);
  }

  static get supportedEntryTypes() {
    return SUPPORTED_ENTRY_TYPES.slice();
  }

  observe(options) {
    if (!options || typeof options !== "object") {
      throw new TypeError("options must be an object");
    }
    if (options.entryTypes !== undefined && options.type !== undefined) {
      throw new TypeError("entryTypes and type cannot be used together");
    }
    var types = [];
    if (options.type !== undefined) {
      types = [String(options.type)];
    } else if (options.entryTypes !== undefined) {
      types = options.entryTypes.slice();
    } else {
      throw new TypeError("Either options.type or options.entryTypes must be provided");
    }
    this._types = types;
    this._buffered = options.buffered === true;
    this._connected = true;

    if (this._buffered) {
      var buf = [];
      var ti = 0;
      while (ti < types.length) {
        var t = types[ti];
        var subset = getEntriesByType(t);
        var si = 0;
        while (si < subset.length) {
          buf.push(subset[si]);
          si = si + 1;
        }
        ti = ti + 1;
      }
      if (buf.length > 0) {
        this._pending = buf;
        this._scheduleNotify();
      }
    }
  }

  disconnect() {
    this._connected = false;
    this._types = [];
    this._pending = [];
  }

  takeRecords() {
    var list = this._pending.slice();
    this._pending = [];
    return list;
  }

  _scheduleNotify() {
    var self = this;
    if (self._notifyScheduled) {
      return;
    }
    self._notifyScheduled = true;
    setImmediate(function () {
      self._notifyScheduled = false;
      if (!self._connected || self._pending.length === 0) {
        return;
      }
      var batch = self._pending.slice();
      self._pending = [];
      var list = new PerformanceObserverEntryList(batch);
      try {
        self._callback(list, self);
      } catch (e) {}
    });
  }
}

// ── GC instrumentation bridge ───────────────────────────────────────────────
function _emitGcEntry(kind, flags, startTime, duration) {
  var entry = _makeEntry("gc", "gc", startTime, duration, { kind: kind, flags: flags });
  entry.kind = kind;
  entry.flags = flags;
  _addEntry(entry);
}

function _startGcMonitor() {
  if (typeof globalThis.__JS_ENGINE_GC === "undefined") {
    return;
  }
  var gc = globalThis.__JS_ENGINE_GC;
  if (gc._perfHookMonitor) {
    return;
  }
  gc._perfHookMonitor = true;
  var lastCycles = 0;
  setInterval(function () {
    if (typeof gc.stats !== "function") {
      return;
    }
    var st = gc.stats();
    if (!st || st.cycles === undefined) {
      return;
    }
    if (st.cycles > lastCycles) {
      _emitGcEntry(constants.NODE_PERFORMANCE_GC_MINOR, constants.NODE_PERFORMANCE_GC_FLAGS_NO, now(), 0);
      lastCycles = st.cycles;
    }
  }, 100);
}

// Public hooks for runtime subsystems (http/net/dns)
function _perfEmitNodeEntry(entryType, name, startTime, duration, detail) {
  if (SUPPORTED_ENTRY_TYPES.indexOf(entryType) < 0) {
    return;
  }
  var entry = _makeEntry(name, entryType, startTime, duration, detail);
  _addEntry(entry);
}

performance._emitNodeEntry = _perfEmitNodeEntry;

if (typeof globalThis !== "undefined") {
    globalThis.performance = performance;
}

module.exports = {
    performance: performance,
    PerformanceObserver: PerformanceObserver,
    PerformanceObserverEntryList: PerformanceObserverEntryList,
    createHistogram: createHistogram,
    monitorEventLoopDelay: monitorEventLoopDelay,
    // Node exports timerify at the module top level (not only on performance).
    timerify: timerify,
    constants: constants,
    /** @private Runtime bridge for http/net/dns instrumentation */
    _emitNodeEntry: _perfEmitNodeEntry
};
