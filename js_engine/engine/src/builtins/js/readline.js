// ────────────────────────────────────────────────────────────────────────────
// builtins/js/readline.js — Node.js `readline` module
//
// Provides line-by-line reading from Readable streams (typically stdin).
//
// require("readline").createInterface(options) — create Interface
// require("readline/promises").createInterface(options) — async variant
//
// Node.js reference: https://nodejs.org/api/readline.html
// ────────────────────────────────────────────────────────────────────────────

var EventEmitter = require("events");

// ── Interface ───────────────────────────────────────────────────────────────
// The core readline Interface class.  Extends EventEmitter with:
//   "line"  — emitted for each completed line of input
//   "close" — emitted when the interface is closed
//
// In interactive mode (TTY), it manages prompt display and line editing.
// In non-interactive mode (pipe), it buffers input and emits lines.

function Interface(options) {
    EventEmitter.init.call(this);

    if (typeof options === "undefined") {
        options = {};
    }

    this.input = options.input || null;
    this.output = options.output || null;
    this.terminal = options.terminal !== undefined
        ? options.terminal
        : (this.output !== null && this.output.isTTY === true);

    this._prompt = options.prompt !== undefined ? options.prompt : "> ";
    this._closed = false;
    this._line_buffer = "";
    this._questionCallback = null;

    // If input is given, start listening for data
    if (this.input !== null && typeof this.input.on === "function") {
        var self = this;
        this.input.on("data", function(chunk) {
            if (self._closed) { return; }
            self._onData(typeof chunk === "string" ? chunk : "" + chunk);
        });
        this.input.on("end", function() {
            if (self._closed) {
                return;
            }
            // Flush any remaining buffer as a final line
            if (self._line_buffer.length > 0) {
                var remaining = self._line_buffer;
                self._line_buffer = "";
                self._onLine(remaining);
            }
            self.close();
        });
    }
}

Interface.prototype = Object.create(EventEmitter.prototype);
Interface.prototype.constructor = Interface;

/**
 * Process incoming data — split on newlines and emit "line" events.
 */
Interface.prototype._onData = function(data) {
    this._line_buffer = this._line_buffer + data;
    var idx = this._line_buffer.indexOf("\n");
    while (idx !== -1) {
        var line = this._line_buffer.substring(0, idx);
        // Strip trailing \r for Windows-style \r\n
        if (line.length > 0 && line[line.length - 1] === "\r") {
            line = line.substring(0, line.length - 1);
        }
        this._line_buffer = this._line_buffer.substring(idx + 1);
        this._onLine(line);
        idx = this._line_buffer.indexOf("\n");
    }
};

/**
 * Handle a complete line — dispatch to question callback or emit "line".
 */
Interface.prototype._onLine = function(line) {
    if (this._questionCallback !== null) {
        var cb = this._questionCallback;
        this._questionCallback = null;
        cb(line);
    } else {
        this.emit("line", line);
    }
};

/**
 * Display a query to the user and call callback with their response.
 * Node.js ref: readline.Interface.question(query[, options], callback)
 */
Interface.prototype.question = function(query, callback) {
    if (typeof query === "function") {
        callback = query;
        query = "";
    }
    if (this.output !== null && typeof this.output.write === "function") {
        this.output.write(query);
    }
    this._questionCallback = callback;
};

/**
 * Write the prompt to the output stream.
 */
Interface.prototype.prompt = function(preserveCursor) {
    if (this.output !== null && typeof this.output.write === "function") {
        this.output.write(this._prompt);
    }
};

/**
 * Set the prompt string.
 */
Interface.prototype.setPrompt = function(prompt) {
    this._prompt = prompt;
};

/**
 * Get the current prompt string.
 */
Interface.prototype.getPrompt = function() {
    return this._prompt;
};

/**
 * Write data to the output stream (passthrough utility).
 */
Interface.prototype.write = function(data) {
    if (this._closed) { return; }
    if (data !== null && data !== undefined) {
        this._onData(typeof data === "string" ? data : "" + data);
    }
};

/**
 * Close the Interface, emitting "close" event.
 */
Interface.prototype.close = function() {
    if (this._closed) { return; }
    this._closed = true;
    this.emit("close");
};

/**
 * Pause the input stream.
 */
Interface.prototype.pause = function() {
    if (this.input !== null && typeof this.input.pause === "function") {
        this.input.pause();
    }
    return this;
};

/**
 * Resume the input stream.
 */
Interface.prototype.resume = function() {
    if (this.input !== null && typeof this.input.resume === "function") {
        this.input.resume();
    }
    return this;
};

// ── PromiseInterface ────────────────────────────────────────────────────────
// Wraps Interface with promise-returning methods.

function PromiseInterface(options) {
    this._rl = new Interface(options);
}

/**
 * Ask a question, returns a Promise that resolves with the answer.
 */
PromiseInterface.prototype.question = function(query) {
    var rl = this._rl;
    return new Promise(function(resolve) {
        rl.question(query, function(answer) {
            resolve(answer);
        });
    });
};

PromiseInterface.prototype.close = function() {
    this._rl.close();
};

PromiseInterface.prototype.on = function(event, listener) {
    this._rl.on(event, listener);
    return this;
};

PromiseInterface.prototype.once = function(event, listener) {
    this._rl.once(event, listener);
    return this;
};

// Forward common properties
Object.defineProperty(PromiseInterface.prototype, "line", {
    get: function() { return this._rl._line_buffer; }
});

// ── Factory functions ───────────────────────────────────────────────────────

function createInterface(options) {
    // Handle (input, output, completer, terminal) positional args
    if (options && typeof options.input === "undefined" && typeof options.on !== "function") {
        // options is already an options object — use as-is
    } else if (typeof options === "object" && typeof options.on === "function") {
        // First arg is a stream: createInterface(input, output, completer, terminal)
        options = { input: options };
    }
    return new Interface(options);
}

// ── readline/promises ───────────────────────────────────────────────────────

var promises = {};

promises.createInterface = function(options) {
    if (options && typeof options.input === "undefined" && typeof options.on === "function") {
        options = { input: options };
    }
    return new PromiseInterface(options);
};

// ── Module exports ──────────────────────────────────────────────────────────

// ── TTY cursor helpers (Node readline.cursorTo & co.) ──────────────────────
// Write the same ANSI sequences as Node, and only to a TTY stream (Node writes
// unconditionally, but a redirected stream would just collect escape bytes).
// Vite's logger calls readline.cursorTo(process.stdout, 0, 0) +
// readline.clearScreenDown(process.stdout) to clear the screen on a TTY; the
// missing exports threw from inside its error middleware.
function _ttyWrite(stream, seq, callback) {
    if (stream && stream.isTTY && typeof stream.write === "function") {
        stream.write(seq);
    }
    if (typeof callback === "function") { callback(); }
    return true;
}

function cursorTo(stream, x, y, callback) {
    if (typeof y === "function") { callback = y; y = undefined; }
    if (typeof x !== "number" || x !== x) {
        if (typeof callback === "function") { callback(); }
        return true;
    }
    var seq = typeof y === "number" && y === y
        ? "\x1b[" + (y + 1) + ";" + (x + 1) + "H"
        : "\x1b[" + (x + 1) + "G";
    return _ttyWrite(stream, seq, callback);
}

function moveCursor(stream, dx, dy, callback) {
    var seq = "";
    if (dx < 0) { seq += "\x1b[" + (-dx) + "D"; } else if (dx > 0) { seq += "\x1b[" + dx + "C"; }
    if (dy < 0) { seq += "\x1b[" + (-dy) + "A"; } else if (dy > 0) { seq += "\x1b[" + dy + "B"; }
    return _ttyWrite(stream, seq, callback);
}

// dir: -1 = to the start of the line, 1 = to the end, 0 = the whole line
function clearLine(stream, dir, callback) {
    var seq = dir < 0 ? "\x1b[1K" : (dir > 0 ? "\x1b[0K" : "\x1b[2K");
    return _ttyWrite(stream, seq, callback);
}

function clearScreenDown(stream, callback) {
    return _ttyWrite(stream, "\x1b[0J", callback);
}

// Keypress decoding is not implemented; accept the call (Vite's CLI shortcuts
// invoke it) without emitting 'keypress' events.
function emitKeypressEvents(stream) {}

module.exports = {
    createInterface: createInterface,
    Interface: Interface,
    promises: promises,
    cursorTo: cursorTo,
    moveCursor: moveCursor,
    clearLine: clearLine,
    clearScreenDown: clearScreenDown,
    emitKeypressEvents: emitKeypressEvents
};
