"use strict";

/**
 * Helpers for deterministic event-loop ordering regression tests.
 */
function createOrder() {
  return [];
}

function joinOrder(order) {
  return order.join(",");
}

function indexOf(order, label) {
  return order.indexOf(label);
}

function assertBefore(order, a, b, assertFn, msg) {
  var ia = indexOf(order, a);
  var ib = indexOf(order, b);
  assertFn(ia !== -1 && ib !== -1 && ia < ib, msg);
}

function waitMacrotick(ms) {
  return new Promise(function (resolve) {
    setTimeout(resolve, ms);
  });
}

module.exports = {
  createOrder: createOrder,
  joinOrder: joinOrder,
  indexOf: indexOf,
  assertBefore: assertBefore,
  waitMacrotick: waitMacrotick,
};
