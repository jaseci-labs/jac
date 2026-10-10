// internal/assert/myers_diff.js — Myers diff used by assert's error output.
// Port of Node lib/internal/assert/myers_diff.js (exposed to tests via
// require('internal/assert/myers_diff') under --expose-internals).

'use strict';

// Node routes color codes through internal/util/colors (TTY-aware). The engine
// builds assertion diffs colorless, so blank codes + hasColors:false keep the
// printers' output shape without escape sequences.
var colors = {
    white: '',
    green: '',
    red: '',
    blue: '',
    gray: '',
    hasColors: false
};

var kNopLinesToCollapse = 5;
var kOperations = {
    DELETE: -1,
    NOP: 0,
    INSERT: 1
};

function areLinesEqual(actual, expected, checkCommaDisparity) {
    if (actual === expected) {
        return true;
    }
    if (checkCommaDisparity) {
        return (actual + ',') === expected || actual === (expected + ',');
    }
    return false;
}

function myersDiff(actual, expected, checkCommaDisparity) {
    if (checkCommaDisparity === undefined) { checkCommaDisparity = false; }
    var actualLength = actual.length;
    var expectedLength = expected.length;
    var max = actualLength + expectedLength;

    if (max > 2147483647) {
        var err = new RangeError(
            'The value of "myersDiff input size" is out of range. ' +
            'It must be < 2^31. Received ' + max);
        err.code = 'ERR_OUT_OF_RANGE';
        throw err;
    }

    var v = new Int32Array(2 * max + 1);
    var trace = [];

    for (var diffLevel = 0; diffLevel <= max; diffLevel++) {
        trace.push(new Int32Array(v)); // Clone the current state of `v`

        for (var diagonalIndex = -diffLevel; diagonalIndex <= diffLevel; diagonalIndex += 2) {
            var offset = diagonalIndex + max;
            var previousOffset = v[offset - 1];
            var nextOffset = v[offset + 1];
            var x = diagonalIndex === -diffLevel ||
                (diagonalIndex !== diffLevel && previousOffset < nextOffset) ?
                nextOffset :
                previousOffset + 1;
            var y = x - diagonalIndex;

            while (
                x < actualLength &&
                y < expectedLength &&
                areLinesEqual(actual[x], expected[y], checkCommaDisparity)
            ) {
                x++;
                y++;
            }

            v[offset] = x;

            if (x >= actualLength && y >= expectedLength) {
                return backtrack(trace, actual, expected, checkCommaDisparity);
            }
        }
    }
}

function backtrack(trace, actual, expected, checkCommaDisparity) {
    var actualLength = actual.length;
    var expectedLength = expected.length;
    var max = actualLength + expectedLength;

    var x = actualLength;
    var y = expectedLength;
    var result = [];

    for (var diffLevel = trace.length - 1; diffLevel >= 0; diffLevel--) {
        var v = trace[diffLevel];
        var diagonalIndex = x - y;
        var offset = diagonalIndex + max;

        var prevDiagonalIndex;
        if (
            diagonalIndex === -diffLevel ||
            (diagonalIndex !== diffLevel && v[offset - 1] < v[offset + 1])
        ) {
            prevDiagonalIndex = diagonalIndex + 1;
        } else {
            prevDiagonalIndex = diagonalIndex - 1;
        }

        var prevX = v[prevDiagonalIndex + max];
        var prevY = prevX - prevDiagonalIndex;

        while (x > prevX && y > prevY) {
            var actualItem = actual[x - 1];
            var value = checkCommaDisparity && !String.prototype.endsWith.call(actualItem, ',') ?
                expected[y - 1] : actualItem;
            result.push([kOperations.NOP, value]);
            x--;
            y--;
        }

        if (diffLevel > 0) {
            if (x > prevX) {
                result.push([kOperations.INSERT, actual[--x]]);
            } else {
                result.push([kOperations.DELETE, expected[--y]]);
            }
        }
    }

    return result;
}

function printSimpleMyersDiff(diff) {
    var message = '';

    for (var diffIdx = diff.length - 1; diffIdx >= 0; diffIdx--) {
        var operation = diff[diffIdx][0];
        var value = diff[diffIdx][1];
        var color = colors.white;

        if (operation === kOperations.INSERT) {
            color = colors.green;
        } else if (operation === kOperations.DELETE) {
            color = colors.red;
        }

        message += color + value + colors.white;
    }

    return '\n' + message;
}

function printMyersDiff(diff, operator) {
    var message = '';
    var skipped = false;
    var nopCount = 0;

    for (var diffIdx = diff.length - 1; diffIdx >= 0; diffIdx--) {
        var operation = diff[diffIdx][0];
        var value = diff[diffIdx][1];
        var previousOperation = diffIdx < diff.length - 1 ? diff[diffIdx + 1][0] : null;

        // Avoid grouping if only one line would have been grouped otherwise
        if (previousOperation === kOperations.NOP && operation !== previousOperation) {
            if (nopCount === kNopLinesToCollapse + 1) {
                message += colors.white + '  ' + diff[diffIdx + 1][1] + '\n';
            } else if (nopCount === kNopLinesToCollapse + 2) {
                message += colors.white + '  ' + diff[diffIdx + 2][1] + '\n';
                message += colors.white + '  ' + diff[diffIdx + 1][1] + '\n';
            } else if (nopCount >= kNopLinesToCollapse + 3) {
                message += colors.blue + '...' + colors.white + '\n';
                message += colors.white + '  ' + diff[diffIdx + 1][1] + '\n';
                skipped = true;
            }
            nopCount = 0;
        }

        if (operation === kOperations.INSERT) {
            if (operator === 'partialDeepStrictEqual') {
                message += colors.gray + (colors.hasColors ? ' ' : '+') + ' ' + value + colors.white + '\n';
            } else {
                message += colors.green + '+' + colors.white + ' ' + value + '\n';
            }
        } else if (operation === kOperations.DELETE) {
            message += colors.red + '-' + colors.white + ' ' + value + '\n';
        } else if (operation === kOperations.NOP) {
            if (nopCount < kNopLinesToCollapse) {
                message += colors.white + '  ' + value + '\n';
            }
            nopCount++;
        }
    }

    message = message.replace(/\s+$/, '');

    return { message: '\n' + message, skipped: skipped };
}

module.exports = { myersDiff: myersDiff, printMyersDiff: printMyersDiff, printSimpleMyersDiff: printSimpleMyersDiff };
