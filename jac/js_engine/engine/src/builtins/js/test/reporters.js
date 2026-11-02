// node:test/reporters — minimal built-in reporter stubs (Wave 18)

function _noopReporter() {
    return {
        on: function () { return this; },
        once: function () { return this; },
        emit: function () { return false; }
    };
}

function spec() { return _noopReporter(); }
function tap() { return _noopReporter(); }
function dot() { return _noopReporter(); }
function junit() { return _noopReporter(); }
function lcov() { return _noopReporter(); }

module.exports = {
    spec: spec,
    tap: tap,
    dot: dot,
    junit: junit,
    lcov: lcov
};
