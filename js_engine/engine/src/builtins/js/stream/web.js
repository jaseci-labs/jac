/**
 * stream/web — Node.js `stream/web` / `node:stream/web`
 *
 * Re-exports WHATWG streams from globals (ReadableStream from fetch.js,
 * WritableStream/TransformStream from webstreams.js).
 */
'use strict';

// Ensure writable/transform side is loaded (sets globalThis.*).
try {
    require('webstreams');
} catch (_e) {
    // If webstreams is not registered yet, rely on already-bootstrapped globals.
}

module.exports = {
    ReadableStream: globalThis.ReadableStream,
    ReadableStreamDefaultReader: globalThis.ReadableStreamDefaultReader,
    WritableStream: globalThis.WritableStream,
    WritableStreamDefaultWriter: globalThis.WritableStreamDefaultWriter,
    WritableStreamDefaultController: globalThis.WritableStreamDefaultController,
    TransformStream: globalThis.TransformStream,
    TransformStreamDefaultController: globalThis.TransformStreamDefaultController,
    CountQueuingStrategy: globalThis.CountQueuingStrategy,
    ByteLengthQueuingStrategy: globalThis.ByteLengthQueuingStrategy
};
