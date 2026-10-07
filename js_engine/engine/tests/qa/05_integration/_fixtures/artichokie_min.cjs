"use strict";
// Minimal artichokie subset for js_engine worker_threads regression (terser/Less patterns).
const { MessageChannel, Worker: NodeWorker, receiveMessageOnPort } = require("worker_threads");

const AsyncFunction = async function () {}.constructor;

function genWorkerCode(fn, parentFunctions) {
    const fnString = fn.toString();
    return `
const { parentPort, receiveMessageOnPort, workerData } = require('worker_threads');
const { performance } = require('perf_hooks');
const [parentFunctionSyncMessagePort, parentFunctionAsyncMessagePort, lockState] = workerData;
const createLock = ${function (performance, lockState) {
        return {
            lock: () => { Atomics.store(lockState, 0, 1); },
            waitUnlock: () => {
                while (true) {
                    const status = Atomics.wait(lockState, 0, 1, 5000);
                    if (status === "timed-out") {
                        const u = performance.eventLoopUtilization();
                        if (u && u.utilization > 0.9) continue;
                        throw new Error(status);
                    }
                    break;
                }
            },
        };
    }.toString()}
const parentFunctionRequester = (${function (syncPort, asyncPort, receive, lock) {
        let id = 0;
        const resolvers = new Map();
        const call = (key) => (...args) => {
            id++;
            syncPort.postMessage({ id, name: key, args });
            const got = receive(syncPort);
            if (!got) {
                throw new Error("missing parent function response");
            }
            const resArgs = got.message;
            if (resArgs.isAsync) {
                let resolve, reject;
                const promise = new Promise((res, rej) => { resolve = res; reject = rej; });
                resolvers.set(id, { resolve, reject });
                return promise;
            }
            if ("error" in resArgs) throw resArgs.error;
            return resArgs.result;
        };
        asyncPort.on("message", (args) => {
            if (resolvers.has(args.id)) {
                const { resolve, reject } = resolvers.get(args.id);
                resolvers.delete(args.id);
                if ("result" in args) resolve(args.result);
                else reject(args.error);
            }
        });
        return { call };
    }.toString()})(
  parentFunctionSyncMessagePort,
  parentFunctionAsyncMessagePort,
  receiveMessageOnPort,
  createLock(performance, lockState)
);
${Object.keys(parentFunctions).map((key) => `const ${key} = parentFunctionRequester.call(${JSON.stringify(key)});`).join("\n")}
const _doWorkInit = (${fnString})();
let doWork = (typeof _doWorkInit === "object" && _doWorkInit !== null && typeof _doWorkInit.then === "function")
  ? null
  : _doWorkInit;
const doWorkPromise = doWork === null ? _doWorkInit : null;
parentPort.on("message", async (args) => {
  const work = doWork || await doWorkPromise;
  try {
    const res = await work(...args.args);
    parentPort.postMessage({ result: res });
  } catch (e) {
    parentPort.postMessage({ error: e });
  }
});
`;
}

function createParentFunctionResponder(parentFunctions) {
    const lockState = new Int32Array(new SharedArrayBuffer(4));
    const unlock = () => {
        Atomics.store(lockState, 0, 0);
        Atomics.notify(lockState, 0);
    };
    const parentFunctionSyncMessageChannel = new MessageChannel();
    const parentFunctionAsyncMessageChannel = new MessageChannel();
    const parentFunctionSyncMessagePort = parentFunctionSyncMessageChannel.port1;
    const parentFunctionAsyncMessagePort = parentFunctionAsyncMessageChannel.port1;
    const syncResponse = (data) => {
        parentFunctionSyncMessagePort.postMessage(data);
        unlock();
    };
    parentFunctionSyncMessagePort.on("message", async (args) => {
        let syncResult;
        try {
            syncResult = parentFunctions[args.name](...args.args);
        } catch (error) {
            syncResponse({ id: args.id, error });
            return;
        }
        if (!(typeof syncResult === "object" && syncResult !== null && "then" in syncResult && typeof syncResult.then === "function")) {
            syncResponse({ id: args.id, result: syncResult });
            return;
        }
        syncResponse({ id: args.id, isAsync: true });
        try {
            const result = await syncResult;
            parentFunctionAsyncMessagePort.postMessage({ id: args.id, result });
        } catch (error) {
            parentFunctionAsyncMessagePort.postMessage({ id: args.id, error });
        }
    });
    return {
        close: () => {
            parentFunctionSyncMessagePort.close();
            parentFunctionAsyncMessagePort.close();
        },
        lockState,
        workerPorts: {
            sync: parentFunctionSyncMessageChannel.port2,
            async: parentFunctionAsyncMessageChannel.port2,
        },
    };
}

class Worker {
    constructor(fn, options = {}) {
        this._code = genWorkerCode(fn, options.parentFunctions || {});
        this._parentFunctions = options.parentFunctions || {};
        this._pool = [];
        this._idlePool = [];
    }
    _createWorker(parentFunctionResponder) {
        const options = {
            workerData: [
                parentFunctionResponder.workerPorts.sync,
                parentFunctionResponder.workerPorts.async,
                parentFunctionResponder.lockState,
            ],
            transferList: [
                parentFunctionResponder.workerPorts.sync,
                parentFunctionResponder.workerPorts.async,
            ],
        };
        return new NodeWorker(this._code, { ...options, eval: true });
    }
    async _getAvailableWorker() {
        if (this._idlePool.length) return this._idlePool.shift();
        const parentFunctionResponder = createParentFunctionResponder(this._parentFunctions);
        const worker = this._createWorker(parentFunctionResponder);
        worker.on("message", (args) => {
            if ("result" in args) worker.currentResolve && worker.currentResolve(args.result);
            else worker.currentReject && worker.currentReject(args.error);
            worker.currentResolve = null;
            worker.currentReject = null;
            this._idlePool.push(worker);
        });
        worker.on("error", (err) => {
            if (worker.currentReject) worker.currentReject(err);
            parentFunctionResponder.close();
        });
        this._pool.push(worker);
        return new Promise((resolve, reject) => {
            worker.once("online", () => resolve(worker));
            worker.once("error", reject);
        });
    }
    async run(...args) {
        const worker = await this._getAvailableWorker();
        return new Promise((resolve, reject) => {
            worker.currentResolve = resolve;
            worker.currentReject = reject;
            worker.postMessage({ args });
        });
    }
    stop() {
        this._pool.forEach((w) => w.terminate && w.terminate());
        this._pool = [];
        this._idlePool = [];
    }
}

class FakeWorker {
    constructor(fn, options = {}) {
        const parentFunctions = options.parentFunctions || {};
        const fnString = fn.toString();
        const code = `
${Object.keys(parentFunctions).map((key) => `const ${key} = parentFunctions[${JSON.stringify(key)}];`).join("\n")}
return await (${fnString})()
`;
        this._fn = new AsyncFunction("parentFunctions", code);
        this._parentFunctions = parentFunctions;
    }
    async run(...args) {
        const work = await this._fn(this._parentFunctions);
        return work(...args);
    }
    stop() {}
}

class WorkerWithFallback {
    constructor(fn, options) {
        this._shouldUseFake = options.shouldUseFake;
        this._realWorker = new Worker(fn, options);
        this._fakeWorker = new FakeWorker(fn, options);
    }
    async run(...args) {
        const useFake = this._shouldUseFake && this._shouldUseFake(...args);
        return (useFake ? this._fakeWorker : this._realWorker).run(...args);
    }
    stop() {
        this._realWorker.stop();
        this._fakeWorker.stop();
    }
}

module.exports = { Worker, FakeWorker, WorkerWithFallback };
