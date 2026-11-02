/**
 * cluster.js — minimal Node.js `node:cluster` stub.
 *
 * Full multi-process clustering is out of scope. This stub satisfies test
 * harness probes (e.g. test/common checking cluster.isPrimary) and reports
 * that the current process is the primary/master.
 */

"use strict";

var workers = Object.create(null);

function fork() {
  var err = new Error(
    "cluster.fork() is not implemented in js_engine (single-process runtime)"
  );
  err.code = "ERR_METHOD_NOT_IMPLEMENTED";
  throw err;
}

function setupPrimary() {
  // no-op: already primary
}

function setupMaster() {
  setupPrimary();
}

function disconnect(callback) {
  if (typeof callback === "function") {
    setImmediate(callback);
  }
}

module.exports = {
  isPrimary: true,
  isMaster: true,
  isWorker: false,
  workers: workers,
  settings: Object.create(null),
  schedulingPolicy: 2, // SCHED_RR
  SCHED_NONE: 1,
  SCHED_RR: 2,
  fork: fork,
  setupPrimary: setupPrimary,
  setupMaster: setupMaster,
  disconnect: disconnect,
};
