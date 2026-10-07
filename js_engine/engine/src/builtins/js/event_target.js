// WHATWG Event / CustomEvent / EventTarget (Wave 15)
// Eager-loaded at bootstrap; installs globalThis.Event / CustomEvent / EventTarget.

function Event(type, eventInitDict) {
    if (typeof type !== "string" && typeof type !== "number") {
        // Node/WHATWG coerce non-strings via ToString
        type = String(type);
    }
    var init = eventInitDict || {};
    this.type = String(type);
    this.bubbles = !!init.bubbles;
    this.cancelable = !!init.cancelable;
    this.composed = !!init.composed;
    this.defaultPrevented = false;
    this.cancelBubble = false;
    this._stopImmediate = false;
    this.eventPhase = 0;
    this.target = null;
    this.currentTarget = null;
    this.isTrusted = false;
    this.timeStamp = Date.now ? Date.now() : 0;
    this.srcElement = null;
    this.returnValue = true;
}

Event.NONE = 0;
Event.CAPTURING_PHASE = 1;
Event.AT_TARGET = 2;
Event.BUBBLING_PHASE = 3;
Event.prototype.NONE = 0;
Event.prototype.CAPTURING_PHASE = 1;
Event.prototype.AT_TARGET = 2;
Event.prototype.BUBBLING_PHASE = 3;

Event.prototype.preventDefault = function () {
    if (this.cancelable) {
        this.defaultPrevented = true;
        this.returnValue = false;
    }
};

Event.prototype.stopPropagation = function () {
    this.cancelBubble = true;
};

Event.prototype.stopImmediatePropagation = function () {
    this.cancelBubble = true;
    this._stopImmediate = true;
};

function CustomEvent(type, eventInitDict) {
    Event.call(this, type, eventInitDict);
    var init = eventInitDict || {};
    this.detail = ("detail" in init) ? init.detail : null;
}
CustomEvent.prototype = Object.create(Event.prototype);
CustomEvent.prototype.constructor = CustomEvent;

function EventTarget() {
    this._listeners = Object.create(null);
}

EventTarget.prototype.addEventListener = function (type, listener, options) {
    if (listener == null) return;
    type = String(type);
    var once = false;
    var signal = null;
    if (typeof options === "boolean") {
        // capture ignored (no tree)
    } else if (options && typeof options === "object") {
        once = !!options.once;
        signal = options.signal || null;
    }
    if (!this._listeners[type]) {
        this._listeners[type] = [];
    }
    var list = this._listeners[type];
    var fn = typeof listener === "function" ? listener
        : (listener && typeof listener.handleEvent === "function" ? listener : null);
    if (!fn) return;
    // Deduplicate identical listener registrations
    for (var i = 0; i < list.length; i++) {
        if (list[i].listener === listener) return;
    }
    var entry = { listener: listener, fn: fn, once: once };
    list.push(entry);
    if (signal && typeof signal.addEventListener === "function") {
        var self = this;
        var remove = function () {
            self.removeEventListener(type, listener);
        };
        if (signal.aborted) {
            remove();
            return;
        }
        signal.addEventListener("abort", remove, { once: true });
    }
};

EventTarget.prototype.removeEventListener = function (type, listener) {
    if (!this._listeners) return;
    type = String(type);
    var list = this._listeners[type];
    if (!list) return;
    for (var i = 0; i < list.length; i++) {
        if (list[i].listener === listener) {
            list.splice(i, 1);
            break;
        }
    }
    if (list.length === 0) delete this._listeners[type];
};

EventTarget.prototype.dispatchEvent = function (event) {
    if (!event || typeof event.type !== "string") {
        throw new TypeError("Failed to execute 'dispatchEvent' on 'EventTarget': parameter 1 is not of type 'Event'.");
    }
    if (!this._listeners) this._listeners = Object.create(null);
    event.target = this;
    event.currentTarget = this;
    event.eventPhase = Event.AT_TARGET;
    event.srcElement = this;
    var list = this._listeners[event.type];
    if (!list || list.length === 0) {
        event.eventPhase = Event.NONE;
        event.currentTarget = null;
        return !event.defaultPrevented;
    }
    var snapshot = list.slice();
    for (var i = 0; i < snapshot.length; i++) {
        if (event._stopImmediate) break;
        var entry = snapshot[i];
        if (entry.once) {
            this.removeEventListener(event.type, entry.listener);
        }
        try {
            if (typeof entry.fn === "function") {
                entry.fn.call(this, event);
            } else if (entry.fn && typeof entry.fn.handleEvent === "function") {
                entry.fn.handleEvent(event);
            }
        } catch (e) {
            // Per HTML: report but continue dispatching
            if (typeof console !== "undefined" && console.error) {
                try { console.error(e); } catch (_) {}
            }
        }
    }
    event.eventPhase = Event.NONE;
    event.currentTarget = null;
    return !event.defaultPrevented;
};

globalThis.Event = Event;
globalThis.EventTarget = EventTarget;
globalThis.CustomEvent = CustomEvent;

module.exports = {
    Event: Event,
    EventTarget: EventTarget,
    CustomEvent: CustomEvent
};
