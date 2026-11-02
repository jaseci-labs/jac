/**
 * diagnostics_channel.js — Node.js `diagnostics_channel` / `node:diagnostics_channel`
 *
 * Pure JS MVP: Channel pub/sub + TracingChannel (sync/promise/callback).
 */
'use strict';

var _channels = Object.create(null);

function Channel(name) {
    this.name = name;
    this._subscribers = [];
}

Object.defineProperty(Channel.prototype, 'hasSubscribers', {
    get: function () {
        return this._subscribers.length > 0;
    },
    enumerable: true,
    configurable: true
});

Channel.prototype.subscribe = function (onMessage) {
    if (typeof onMessage !== 'function') {
        var err = new TypeError('The "subscription" argument must be of type function.' +
            ' Received ' + onMessage);
        err.code = 'ERR_INVALID_ARG_TYPE';
        throw err;
    }
    this._subscribers.push(onMessage);
};

Channel.prototype.unsubscribe = function (onMessage) {
    var list = this._subscribers;
    for (var i = 0; i < list.length; i++) {
        if (list[i] === onMessage) {
            list.splice(i, 1);
            return true;
        }
    }
    return false;
};

Channel.prototype.publish = function (message) {
    var list = this._subscribers.slice();
    var name = this.name;
    for (var i = 0; i < list.length; i++) {
        try {
            list[i](message, name);
        } catch (e) {
            // Node isolates subscriber errors; best-effort: rethrow async if possible
            if (typeof process !== 'undefined' && typeof process.nextTick === 'function') {
                process.nextTick(function () { throw e; });
            }
        }
    }
};

function channel(name) {
    if (typeof name !== 'string' && typeof name !== 'symbol') {
        var err = new TypeError('The "name" argument must be of type string or symbol.' +
            ' Received ' + name);
        err.code = 'ERR_INVALID_ARG_TYPE';
        throw err;
    }
    var key = typeof name === 'symbol' ? String(name) : name;
    if (_channels[key] === undefined) {
        _channels[key] = new Channel(name);
    }
    return _channels[key];
}

function hasSubscribers(name) {
    var ch = channel(name);
    return ch.hasSubscribers;
}

function subscribe(name, onMessage) {
    return channel(name).subscribe(onMessage);
}

function unsubscribe(name, onMessage) {
    return channel(name).unsubscribe(onMessage);
}

function TracingChannel(nameOrChannels) {
    if (typeof nameOrChannels === 'string') {
        this.start = channel('tracing:' + nameOrChannels + ':start');
        this.end = channel('tracing:' + nameOrChannels + ':end');
        this.asyncStart = channel('tracing:' + nameOrChannels + ':asyncStart');
        this.asyncEnd = channel('tracing:' + nameOrChannels + ':asyncEnd');
        this.error = channel('tracing:' + nameOrChannels + ':error');
    } else if (nameOrChannels && typeof nameOrChannels === 'object') {
        this.start = nameOrChannels.start || channel('tracing:anon:start');
        this.end = nameOrChannels.end || channel('tracing:anon:end');
        this.asyncStart = nameOrChannels.asyncStart || channel('tracing:anon:asyncStart');
        this.asyncEnd = nameOrChannels.asyncEnd || channel('tracing:anon:asyncEnd');
        this.error = nameOrChannels.error || channel('tracing:anon:error');
    } else {
        var err = new TypeError('The "name" argument must be of type string or Object.');
        err.code = 'ERR_INVALID_ARG_TYPE';
        throw err;
    }
}

Object.defineProperty(TracingChannel.prototype, 'hasSubscribers', {
    get: function () {
        return this.start.hasSubscribers ||
            this.end.hasSubscribers ||
            this.asyncStart.hasSubscribers ||
            this.asyncEnd.hasSubscribers ||
            this.error.hasSubscribers;
    },
    enumerable: true,
    configurable: true
});

TracingChannel.prototype.subscribe = function (handlers) {
    if (!handlers || typeof handlers !== 'object') {
        var err = new TypeError('The "subscribers" argument must be of type Object.');
        err.code = 'ERR_INVALID_ARG_TYPE';
        throw err;
    }
    if (typeof handlers.start === 'function') this.start.subscribe(handlers.start);
    if (typeof handlers.end === 'function') this.end.subscribe(handlers.end);
    if (typeof handlers.asyncStart === 'function') this.asyncStart.subscribe(handlers.asyncStart);
    if (typeof handlers.asyncEnd === 'function') this.asyncEnd.subscribe(handlers.asyncEnd);
    if (typeof handlers.error === 'function') this.error.subscribe(handlers.error);
};

TracingChannel.prototype.unsubscribe = function (handlers) {
    if (!handlers || typeof handlers !== 'object') return false;
    var ok = false;
    if (typeof handlers.start === 'function') ok = this.start.unsubscribe(handlers.start) || ok;
    if (typeof handlers.end === 'function') ok = this.end.unsubscribe(handlers.end) || ok;
    if (typeof handlers.asyncStart === 'function') ok = this.asyncStart.unsubscribe(handlers.asyncStart) || ok;
    if (typeof handlers.asyncEnd === 'function') ok = this.asyncEnd.unsubscribe(handlers.asyncEnd) || ok;
    if (typeof handlers.error === 'function') ok = this.error.unsubscribe(handlers.error) || ok;
    return ok;
};

TracingChannel.prototype.traceSync = function (fn, context, thisArg) {
    context = context || {};
    var args = [];
    for (var i = 3; i < arguments.length; i++) args.push(arguments[i]);
    this.start.publish(context);
    try {
        var result = fn.apply(thisArg, args);
        context.result = result;
        this.end.publish(context);
        return result;
    } catch (err) {
        context.error = err;
        this.error.publish(context);
        this.end.publish(context);
        throw err;
    }
};

TracingChannel.prototype.tracePromise = function (fn, context, thisArg) {
    context = context || {};
    var args = [];
    for (var i = 3; i < arguments.length; i++) args.push(arguments[i]);
    var self = this;
    this.start.publish(context);
    var ret;
    try {
        ret = fn.apply(thisArg, args);
    } catch (err) {
        context.error = err;
        this.error.publish(context);
        this.end.publish(context);
        return Promise.reject(err);
    }
    this.end.publish(context);
    return Promise.resolve(ret).then(
        function (value) {
            context.result = value;
            self.asyncStart.publish(context);
            self.asyncEnd.publish(context);
            return value;
        },
        function (err) {
            context.error = err;
            self.asyncStart.publish(context);
            self.error.publish(context);
            self.asyncEnd.publish(context);
            throw err;
        }
    );
};

TracingChannel.prototype.traceCallback = function (fn, position, context, thisArg) {
    context = context || {};
    var args = [];
    for (var i = 4; i < arguments.length; i++) args.push(arguments[i]);
    if (position === undefined || position === null) position = -1;
    var cbIndex = position < 0 ? args.length + position : position;
    if (cbIndex < 0) cbIndex = 0;
    var callback = args[cbIndex];
    if (typeof callback !== 'function') {
        var err = new TypeError('The "callback" argument must be of type function.');
        err.code = 'ERR_INVALID_ARG_TYPE';
        throw err;
    }
    var self = this;
    args[cbIndex] = function tracedCallback() {
        var cbArgs = [];
        for (var j = 0; j < arguments.length; j++) cbArgs.push(arguments[j]);
        var errArg = cbArgs[0];
        if (errArg) {
            context.error = errArg;
        } else {
            context.result = cbArgs.length > 1 ? cbArgs[1] : undefined;
        }
        self.asyncStart.publish(context);
        if (errArg) self.error.publish(context);
        try {
            return callback.apply(this, cbArgs);
        } finally {
            self.asyncEnd.publish(context);
        }
    };
    this.start.publish(context);
    try {
        var result = fn.apply(thisArg, args);
        this.end.publish(context);
        return result;
    } catch (e) {
        context.error = e;
        this.error.publish(context);
        this.end.publish(context);
        throw e;
    }
};

function tracingChannel(nameOrChannels) {
    return new TracingChannel(nameOrChannels);
}

module.exports = {
    channel: channel,
    Channel: Channel,
    hasSubscribers: hasSubscribers,
    subscribe: subscribe,
    unsubscribe: unsubscribe,
    tracingChannel: tracingChannel,
    TracingChannel: TracingChannel
};
