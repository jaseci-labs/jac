/**
 * stream/consumers — minimal helpers matching node:stream/consumers.
 */
'use strict';

function buffer(stream) {
    return new Promise(function (resolve, reject) {
        if (Buffer.isBuffer(stream)) {
            resolve(stream);
            return;
        }
        if (typeof stream === 'string') {
            resolve(Buffer.from(stream));
            return;
        }
        var chunks = [];
        var settled = false;
        function done(err, buf) {
            if (settled) return;
            settled = true;
            if (err) reject(err);
            else resolve(buf);
        }
        if (stream && typeof stream.on === 'function') {
            stream.on('data', function (c) {
                chunks.push(Buffer.isBuffer(c) ? c : Buffer.from(c));
            });
            stream.on('end', function () { done(null, Buffer.concat(chunks)); });
            stream.on('error', function (e) { done(e); });
            return;
        }
        // Async iterable
        if (stream && typeof stream[Symbol.asyncIterator] === 'function') {
            (async function () {
                try {
                    for await (var chunk of stream) {
                        chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
                    }
                    done(null, Buffer.concat(chunks));
                } catch (e) { done(e); }
            })();
            return;
        }
        done(new TypeError('Invalid stream'));
    });
}

function text(stream) {
    return buffer(stream).then(function (buf) { return buf.toString('utf8'); });
}

function arrayBuffer(stream) {
    return buffer(stream).then(function (buf) {
        return buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength);
    });
}

function blob(stream) {
    return buffer(stream).then(function (buf) {
        if (typeof Blob !== 'undefined') return new Blob([buf]);
        return buf;
    });
}

function json(stream) {
    return text(stream).then(function (t) { return JSON.parse(t); });
}

module.exports = {
    buffer: buffer,
    text: text,
    arrayBuffer: arrayBuffer,
    blob: blob,
    json: json
};
