/** BunStore: Postgres anchor persistence via Bun.sql (P2). */

import { SQL } from "bun";
import { createHash } from "node:crypto";
import { SCHEMA_SQL, SCHEMA_VERSION, PROMOTIONS } from "./bun_schema.js";

// SCHEMA_VERSION and SCHEMA_SQL come from the generated bun_schema.js (baked
// from jaclang.runtimelib.store at artifact-build time) so both hosts hash
// the same bytes.
export const SCHEMA_STAMP_KEY = "schema_fingerprint";

function pgOptionsFromEnv() {
  const host = process.env.JAC_PG_HOST || "127.0.0.1";
  const port = Number(process.env.JAC_PG_PORT || "5432");
  const username = process.env.JAC_PG_USER || "jac";
  const password = process.env.JAC_PG_PASSWORD || "";
  const database = process.env.JAC_PG_DATABASE || "jac";
  const socket = process.env.JAC_PG_SOCKET || "";
  const opts = {
    hostname: host,
    port,
    username,
    password,
    database,
    max: 4,
  };
  if (socket) {
    opts.path = socket;
  }
  return opts;
}

export class BunStore {
  constructor(conninfo = null) {
    this.conninfo = conninfo;
    this._sql = null;
    this._ready = false;
  }

  _ensureSql() {
    if (this._sql) {
      return this._sql;
    }
    this._sql = new SQL(pgOptionsFromEnv());
    return this._sql;
  }

  async _schemaFingerprint(sql, promotions) {
    const res = await sql.unsafe("SHOW server_version_num");
    const raw = Array.isArray(res) && res.length ? String(Object.values(res[0])[0]) : "0";
    const serverMajor = Math.floor(Number(raw) / 10000);
    return computeSchemaFingerprint(SCHEMA_VERSION, serverMajor, SCHEMA_SQL, promotions);
  }

  // Mirrors PgStore._acquire_schema_lock: elect one migrator per database via
  // a session advisory lock; losers poll until the winner stamps the matching
  // fingerprint. Like cpython, applying DDL without the lock after the wait
  // deadline is allowed but warned about.
  async _acquireSchemaLock(sql, fingerprint) {
    const WAIT_SECONDS = 30;
    const POLL_START_MS = 50;
    const POLL_MAX_MS = 500;
    let delayMs = POLL_START_MS;
    const deadline = Date.now() + WAIT_SECONDS * 1000;
    for (;;) {
      try {
        const got = await sql.unsafe("SELECT pg_try_advisory_lock($1)", [SCHEMA_LOCK_KEY]);
        if (Array.isArray(got) && got.length && Boolean(Object.values(got[0])[0])) {
          return true;
        }
      } catch (_) {
        return false; // advisory locks unavailable — proceed unlocked.
      }
      if ((await this._schemaStamp()) === fingerprint) {
        return false;
      }
      if (Date.now() >= deadline) {
        console.warn(
          `waited ${WAIT_SECONDS}s for the schema election; applying schema DDL without it`
        );
        return false;
      }
      await new Promise((r) => setTimeout(r, delayMs));
      delayMs = Math.min(delayMs * 2, POLL_MAX_MS);
    }
  }

  async _releaseSchemaLock(sql) {
    try {
      await sql.unsafe("SELECT pg_advisory_unlock($1)", [SCHEMA_LOCK_KEY]);
    } catch (_) { /* best effort */ }
  }

  async _schemaStamp() {
    try {
      return await this.getKv(SCHEMA_STAMP_KEY);
    } catch (_) {
      return null; // kv_state missing — fresh database.
    }
  }

  async ensureSchema(promotions = PROMOTIONS) {
    const sql = this._ensureSql();
    const fp = await this._schemaFingerprint(sql, promotions);
    if ((await this._schemaStamp()) === fp) {
      this._ready = true;
      return;
    }
    // Schema election: only one host/process migrates; the rest wait for the
    // matching stamp (same protocol as PgStore.ensure_schema).
    const held = await this._acquireSchemaLock(sql, fp);
    try {
      if ((await this._schemaStamp()) === fp) {
        this._ready = true;
        return;
      }
      await sql.unsafe("SET lock_timeout = '5s'");
      try {
        for (const stmt of SCHEMA_SQL) {
          await sql.unsafe(stmt);
        }
        // Migration: anchors.seq is required by hydration's ORDER BY seq.
        const hasSeq = await sql.unsafe(
          "SELECT 1 FROM information_schema.columns"
            + " WHERE table_name = 'anchors' AND column_name = 'seq'"
        );
        if (!Array.isArray(hasSeq) || hasSeq.length === 0) {
          await sql.unsafe(
            "ALTER TABLE anchors ADD COLUMN IF NOT EXISTS seq bigserial"
          );
        }
        await this._applyPromotionDdl(sql, promotions);
      } finally {
        await sql.unsafe("SET lock_timeout = DEFAULT");
      }
      await this.setKv(SCHEMA_STAMP_KEY, fp);
    } finally {
      if (held) {
        await this._releaseSchemaLock(sql);
      }
    }
    this._ready = true;
  }

  async _applyPromotionDdl(sql, promotions) {
    // Mirrors PgStore._apply_promotions exactly (impl/store.impl.jac): jsonb
    // generated column plus an UNCONDITIONAL index, rebuilding a column that
    // exists with the wrong type (e.g. text from the pre-parity bun DDL).
    for (const [arch, fld, col] of promotionColumns(promotions)) {
      try {
        const have = await promotedColumnType(sql, col);
        if (have !== null && have !== "jsonb") {
          await sql.unsafe(`DROP INDEX IF EXISTS idx_${col}`);
          await sql.unsafe(`ALTER TABLE anchors DROP COLUMN IF EXISTS ${col}`);
        }
        await sql.unsafe(
          `ALTER TABLE anchors ADD COLUMN IF NOT EXISTS ${col} jsonb`
            + ` GENERATED ALWAYS AS (props->'archetype'->>'${fld}') STORED`
        );
        await sql.unsafe(
          `CREATE INDEX IF NOT EXISTS idx_${col} ON anchors (${col})`
        );
      } catch (e) {
        console.warn(`promotion ${arch}.${fld} failed: ${e}`);
      }
    }
  }

  async upsert(rows) {
    if (!rows?.length) {
      return;
    }
    const sql = this._ensureSql();
    for (const row of rows) {
      await sql`
        INSERT INTO anchors
          (id, kind, arch_type, arch_module, fingerprint, root_id,
           src, dst, undirected, props, format_version, updated_at)
        VALUES
          (${row.id}, ${row.kind}, ${row.arch_type}, ${row.arch_module},
           ${row.fingerprint || ""}, ${row.root_id || null},
           ${row.src || null}, ${row.dst || null}, ${row.undirected || false},
           ${JSON.stringify(row.props || {})}::jsonb, ${SCHEMA_VERSION}, now())
        ON CONFLICT (id) DO UPDATE SET
          kind = EXCLUDED.kind,
          arch_type = EXCLUDED.arch_type,
          arch_module = EXCLUDED.arch_module,
          fingerprint = EXCLUDED.fingerprint,
          root_id = EXCLUDED.root_id,
          src = EXCLUDED.src,
          dst = EXCLUDED.dst,
          undirected = EXCLUDED.undirected,
          props = EXCLUDED.props,
          format_version = EXCLUDED.format_version,
          updated_at = now()
      `;
    }
  }

  async rows(query, params = []) {
    const sql = this._ensureSql();
    const result = await sql.unsafe(query, Array.isArray(params) ? params : []);
    if (Array.isArray(result)) {
      return result.map((r) => Object.values(r));
    }
    return [];
  }

  async getKv(key) {
    const sql = this._ensureSql();
    const result = await sql.unsafe(
      "SELECT value FROM kv_state WHERE key = $1"
        + " AND (expires_at IS NULL OR expires_at > now()) LIMIT 1",
      [key]
    );
    if (Array.isArray(result) && result.length > 0) {
      const row = result[0];
      return typeof row === "object" ? Object.values(row)[0] : row;
    }
    return null;
  }

  async setKv(key, value) {
    const sql = this._ensureSql();
    await sql.unsafe(
      "INSERT INTO kv_state (key, value, expires_at, updated_at) VALUES ($1, $2, NULL, now()) "
        + "ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()",
      [key, value]
    );
  }

  async close() {
    if (this._sql?.close) {
      await this._sql.close();
    }
    this._sql = null;
    this._ready = false;
  }
}

let _sharedStore = null;

const ROOT_KV_KEY = "__jac_shared_root_id";

// Mirrors PgStore._schema_fingerprint byte for byte so bun and cpython hosts
// compute identical stamps on the same database. Exported for the drift test
// that pins JS output against the Python formula.
export function computeSchemaFingerprint(schemaVersion, serverMajor, schemaSql, promotions) {
  const h = createHash("sha256");
  h.update(String(schemaVersion));
  h.update(String(serverMajor));
  for (const stmt of schemaSql) {
    h.update(stmt);
  }
  // str((arch, fld, col)) on the cpython side renders as this exact string,
  // over sorted(_promotion_columns()) -- a FULL tuple sort, so field order
  // within an arch must not affect the hash.
  const cols = promotionColumns(promotions).sort(cmpTuple);
  for (const [arch, fld, col] of cols) {
    h.update(`('${arch}', '${fld}', '${col}')`);
  }
  return `${schemaVersion}:${h.digest("hex").slice(0, 24)}`;
}

// Lexicographic tuple comparison over string triples -- same ordering as
// Python's sorted() on list[tuple[str, str, str]].
function cmpTuple(a, b) {
  for (let i = 0; i < 3; i++) {
    if (a[i] !== b[i]) {
      return a[i] < b[i] ? -1 : 1;
    }
  }
  return 0;
}

// sha256("jac:ensure_schema")[:8] as signed big-endian int — the same
// advisory-lock key PgStore._schema_lock_key derives from _SCHEMA_LOCK_TAG.
const SCHEMA_LOCK_KEY = BigInt.asIntN(
  64,
  BigInt(
    "0x" + createHash("sha256").update("jac:ensure_schema").digest("hex").slice(0, 16)
  )
);

// Mirrors PgStore._promotion_columns / _sanitize_ident in impl/store.impl.jac.
function sanitizeIdent(name) {
  return String(name).toLowerCase().replace(/[^a-z0-9_]/g, "_");
}

// Mirrors PgStore._promoted_column_type in impl/store.impl.jac.
async function promotedColumnType(sql, col) {
  const result = await sql.unsafe(
    "SELECT data_type FROM information_schema.columns "
      + "WHERE table_name = 'anchors' AND column_name = $1",
    [col.toLowerCase()]
  );
  if (Array.isArray(result) && result.length > 0) {
    const row = result[0];
    const val = typeof row === "object" ? Object.values(row)[0] : row;
    return val === undefined || val === null ? null : String(val);
  }
  return null;
}

function promotionColumns(promotions) {
  const out = [];
  const src = promotions || {};
  for (const arch of Object.keys(src).sort()) {
    const fields = Array.isArray(src[arch]) ? src[arch] : [];
    for (const fld of fields) {
      out.push([String(arch), String(fld), `g_${sanitizeIdent(arch)}_${sanitizeIdent(fld)}`]);
    }
  }
  return out;
}

export async function __jacHydrateGraph(store) {
  // Reference: JacRuntime.get_shared_root + store-backed anchor loading
  // (jaclang/jac0core/impl/runtime.impl.jac). The cpython host resolves a
  // stable root id and loads anchors from the store; the bun host does the
  // same eagerly at boot: stable root id from kv_state, then all anchors
  // belonging to that root rebuilt into the OSP graph.
  // Idempotence guard marks done ONLY on success so a mid-hydration failure
  // can be retried on the next request instead of silently skipping forever.
  if (globalThis.__jacHydrationDone || globalThis.__jacHydrationInFlight) {
    return;
  }
  globalThis.__jacHydrationInFlight = true;
  try {
    const completed = await __jacHydrateGraphInner(store);
    if (completed) {
      globalThis.__jacHydrationDone = true;
    }
  } finally {
    globalThis.__jacHydrationInFlight = false;
  }
}

async function __jacHydrateGraphInner(store) {
  let rootId = await store.getKv(ROOT_KV_KEY);
  if (!rootId) {
    rootId = randomUuid();
    await store.setKv(ROOT_KV_KEY, rootId);
  }
  const C = globalThis.__jacOspCore;
  const tagByName = globalThis.__jacOspTagByName || {};
  function register(obj) {
    if (!C || !C.O || !C.H) {
      return -1;
    }
    let h = C.H.get(obj);
    if (h === undefined) {
      h = C.O.length;
      C.O.push(obj);
      C.H.set(obj, h);
    }
    return h;
  }
  const root = { _jac_type: "Root", _jac_id: rootId };
  globalThis.root = root;
  register(root);
  __jacTrackNode(root, rootId);
  if (!C || typeof C.osp_conn !== "function") {
    // Core not published yet — report incomplete so a later request retries.
    return false;
  }
  const rows = await store.rows(
    "SELECT id, kind, arch_type, src, dst, undirected, props FROM anchors "
      + "WHERE root_id = $1 AND id <> $2 ORDER BY seq",
    [rootId, rootId]
  );
  const byId = new Map();
  byId.set(rootId, root);
  const edgeRows = [];
  for (const r of rows) {
    const id = String(r[0]);
    const kind = String(r[1] || "");
    const archType = String(r[2] || "");
    if (kind === "EdgeAnchor") {
      edgeRows.push(r);
      continue;
    }
    let props = r[6];
    props = normalizeJson(props);
    const obj = Object.assign({}, props);
    obj._jac_id = id;
    obj._jac_type = archType;
    obj._jac_root_id = rootId;
    const tag = tagByName[archType];
    if (tag !== undefined) {
      obj.__tag = tag;
    }
    byId.set(id, obj);
    register(obj);
  }
  for (const r of edgeRows) {
    const srcObj = byId.get(String(r[3] || ""));
    const dstObj = byId.get(String(r[4] || ""));
    if (!srcObj || !dstObj) {
      continue;
    }
    let props = normalizeJson(r[6]);
    const edgeObj = Object.assign({}, props);
    edgeObj._jac_id = String(r[0]);
    const archType = String(r[2] || "");
    const tag = tagByName[archType];
    const undirected = r[5] === true || r[5] === "t" ? 1 : 0;
    C.osp_conn(
      register(srcObj),
      register(dstObj),
      register(edgeObj),
      undirected,
      tag === undefined ? -1 : tag,
      0,
      0
    );
  }
  // Enable write-tracking only after the replay so hydrated rows are not
  // re-pended by the osp_conn hook.
  const rh = C.H.get(root);
  globalThis.__jacHydrationDone = true;
}

function normalizeJson(raw) {
  if (typeof raw === "string") {
    try {
      raw = JSON.parse(raw);
    } catch (_) {
      return {};
    }
  }
  return raw && typeof raw === "object" ? raw : {};
}

export async function __jacInitBunStore() {
  // Ready means schema applied AND hydration completed; a failure in either
  // leaves the gate closed so the next request retries instead of silently
  // running unhydrated for the process lifetime.
  if (_sharedStore?._ready && globalThis.__jacHydrationDone) {
    return _sharedStore;
  }
  const store = _sharedStore || new BunStore();
  if (!store._ready) {
    await store.ensureSchema();
  }
  _sharedStore = store;
  globalThis.__jacBunStore = store;
  await __jacHydrateGraph(store);
  return store;
}

export function __jacGetBunStore() {
  return _sharedStore || globalThis.__jacBunStore || null;
}

function randomUuid() {
  if (globalThis.crypto?.randomUUID) {
    return globalThis.crypto.randomUUID();
  }
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === "x" ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

function nodeProps(obj) {
  const out = {};
  if (!obj || typeof obj !== "object") {
    return out;
  }
  for (const key of Object.keys(obj)) {
    if (key.startsWith("_") || typeof obj[key] === "function") {
      continue;
    }
    out[key] = obj[key];
  }
  return out;
}

function archTypeOf(obj) {
  if (!obj) {
    return "";
  }
  if (obj.constructor?.name && obj.constructor.name !== "Object") {
    return obj.constructor.name;
  }
  return String(obj._jac_type || "");
}

export function __jacEnsureNodeId(node, rootId = null) {
  if (!node || typeof node !== "object") {
    return null;
  }
  if (!node._jac_id) {
    node._jac_id = randomUuid();
  }
  if (rootId && !node._jac_root_id) {
    node._jac_root_id = rootId;
  }
  return node._jac_id;
}

const _pendingRows = [];

export function __jacTrackNode(node, rootId = null) {
  const id = __jacEnsureNodeId(node, rootId);
  if (!id) {
    return;
  }
  _pendingRows.push({
    id,
    kind: "NodeAnchor",
    arch_type: archTypeOf(node),
    arch_module: "",
    fingerprint: "",
    root_id: node._jac_root_id || rootId || null,
    src: null,
    dst: null,
    undirected: false,
    props: nodeProps(node),
  });
}

export function __jacTrackEdge(src, dst, edgeObj = null, undirected = false) {
  const rootId = globalThis.root?._jac_id || null;
  const srcId = __jacEnsureNodeId(src, rootId);
  const dstId = __jacEnsureNodeId(dst, rootId);
  if (!srcId || !dstId) {
    return;
  }
  __jacTrackNode(src, rootId);
  __jacTrackNode(dst, rootId);
  const edgeId = edgeObj?._jac_id || randomUuid();
  if (edgeObj && !edgeObj._jac_id) {
    edgeObj._jac_id = edgeId;
  }
  _pendingRows.push({
    id: edgeId,
    kind: "EdgeAnchor",
    arch_type: archTypeOf(edgeObj),
    arch_module: "",
    fingerprint: "",
    root_id: rootId,
    src: srcId,
    dst: dstId,
    undirected: !!undirected,
    props: nodeProps(edgeObj),
  });
}

export async function __jacCommitGraph() {
  const store = __jacGetBunStore();
  if (!store || !_pendingRows.length) {
    return;
  }
  const batch = _pendingRows.splice(0, _pendingRows.length);
  await store.upsert(batch);
}

export function __jacEnsureRoot() {
  if (globalThis.root?._jac_id) {
    return globalThis.root;
  }
  // Root id normally comes from hydration (stable across restarts); only
  // mint a transient one when no store is available yet.
  const root = { _jac_type: "Root", _jac_id: randomUuid() };
  globalThis.root = root;
  __jacTrackNode(root, root._jac_id);
  return root;
}

export function __jacInstallOspPersistHooks() {
  if (globalThis.__jacOspPersistInstalled) {
    return;
  }
  const C = globalThis.__jacOspCore;
  if (!C || typeof C.osp_conn !== "function") {
    // Core not published yet — retry on the next request.
    return;
  }
  globalThis.__jacOspPersistInstalled = true;
  __jacEnsureRoot();
  // Generated code reaches the graph exclusively through the shared core
  // (__jacOspCore.osp_conn), so persistence hooks wrap that entry point.
  const origConn = C.osp_conn;
  C.osp_conn = (srcH, dstH, edgeH, undirected, tag, rgnSrc, rgnTgt) => {
    const out = origConn(srcH, dstH, edgeH, undirected, tag, rgnSrc, rgnTgt);
    if (globalThis.__jacHydrationDone) {
      try {
        const O = C.O || [];
        __jacTrackEdge(O[srcH], O[dstH], O[edgeH], undirected === 1 || undirected === true);
      } catch (_) {
        /* never let bookkeeping break the graph write */
      }
    }
    return out;
  };
}

export async function __jacServerSpawnWalker(walkerInst) {
  __jacInstallOspPersistHooks();
  await __jacInitBunStore();
  try {
    if (walkerInst?.__jac_run) {
      const result = await walkerInst.__jac_run();
      await __jacCommitGraph();
      return result;
    }
    // Reference: ExecutionManager.spawn_walker_sync in
    // jaclang/runtimelib/impl/server.impl.jac — instantiate the walker,
    // resolve the target node (_jac_spawn_node override or the shared
    // root), then hand off to the OSP spawn primitive.
    const C = globalThis.__jacOspCore;
    if (C && typeof C.osp_spawn === "function") {
      const tag = walkerInst?.constructor?.prototype?.__tag;
      const wdesc = (globalThis.__jacOspDesc || {})[tag];
      const rt = globalThis.__jacOspRT;
      let starts = [globalThis.root];
      const spawnNodeId = walkerInst?._jac_spawn_node;
      if (spawnNodeId) {
        delete walkerInst._jac_spawn_node;
        for (const o of C.O || []) {
          if (o && o._jac_id === spawnNodeId) {
            starts = [o];
            break;
          }
        }
      }
      if (!rt || !wdesc) {
        throw new Error(
          "No walker descriptor/runtime available for Bun host (missing __jacOspRT or __jacOspDesc)"
        );
      }
      const result = await C.osp_spawn(rt, walkerInst, wdesc, starts);
      if (result && typeof result === "object" && !result.reports) {
        result.reports = walkerInst.reports || [];
      }
      await __jacCommitGraph();
      return result;
    }
    throw new Error("No walker runtime available for Bun host");
  } catch (e) {
    _pendingRows.length = 0;
    throw e;
  }
}
