/** BunStore: Postgres anchor persistence via Bun.sql (P2). */

import { SQL } from "bun";

export const SCHEMA_VERSION = 1;
export const SCHEMA_STAMP_KEY = "schema_fingerprint";

const SCHEMA_SQL = [
  `CREATE TABLE IF NOT EXISTS anchors (
        id             uuid PRIMARY KEY,
        kind           text NOT NULL,
        arch_type      text NOT NULL DEFAULT '',
        arch_module    text NOT NULL DEFAULT '',
        fingerprint    text NOT NULL DEFAULT '',
        root_id        uuid,
        src            uuid,
        dst            uuid,
        undirected     boolean NOT NULL DEFAULT false,
        props          jsonb NOT NULL DEFAULT '{}'::jsonb,
        format_version integer NOT NULL DEFAULT 1,
        updated_at     timestamptz NOT NULL DEFAULT now(),
        seq            bigserial
    )`,
  `CREATE INDEX IF NOT EXISTS idx_anchors_src
        ON anchors (src, arch_type) WHERE src IS NOT NULL`,
  `CREATE INDEX IF NOT EXISTS idx_anchors_dst
        ON anchors (dst, arch_type) WHERE dst IS NOT NULL`,
  `CREATE INDEX IF NOT EXISTS idx_anchors_kind_type
        ON anchors (kind, arch_type)`,
  `CREATE INDEX IF NOT EXISTS idx_anchors_root
        ON anchors (root_id) WHERE root_id IS NOT NULL`,
  `CREATE TABLE IF NOT EXISTS graph_types (
        type_name text NOT NULL,
        ancestor  text NOT NULL,
        PRIMARY KEY (type_name, ancestor)
    )`,
  `CREATE TABLE IF NOT EXISTS kv_state (
        key        text PRIMARY KEY,
        value      text NOT NULL,
        expires_at timestamptz,
        updated_at timestamptz NOT NULL DEFAULT now()
    )`,
  `CREATE TABLE IF NOT EXISTS quarantine (
        missing_id  uuid NOT NULL,
        referrer_id uuid,
        kind        text NOT NULL,
        created_at  timestamptz NOT NULL DEFAULT now(),
        PRIMARY KEY (missing_id, kind)
    )`,
];

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

  async ensureSchema(_promotions = {}) {
    const sql = this._ensureSql();
    for (const stmt of SCHEMA_SQL) {
      await sql.unsafe(stmt);
    }
    await sql`
      INSERT INTO kv_state (key, value, expires_at, updated_at)
      VALUES (${SCHEMA_STAMP_KEY}, ${String(SCHEMA_VERSION)}, NULL, now())
      ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()
    `;
    this._ready = true;
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

  async rows(query, _params = {}) {
    const sql = this._ensureSql();
    const result = await sql.unsafe(query);
    if (Array.isArray(result)) {
      return result.map((r) => Object.values(r));
    }
    return [];
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

export async function __jacInitBunStore() {
  if (_sharedStore?._ready) {
    return _sharedStore;
  }
  const store = new BunStore();
  await store.ensureSchema({});
  _sharedStore = store;
  globalThis.__jacBunStore = store;
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
  const root = { _jac_type: "Root", _jac_id: randomUuid() };
  globalThis.root = root;
  __jacTrackNode(root, root._jac_id);
  return root;
}

export function __jacInstallOspPersistHooks() {
  if (globalThis.__jacOspPersistInstalled) {
    return;
  }
  globalThis.__jacOspPersistInstalled = true;
  __jacEnsureRoot();
  const orig = globalThis.__ospConnW;
  if (typeof orig === "function") {
    globalThis.__ospConnW = (src, tgt, mkEdge, undirected, tag = -1) => {
      const edge = typeof mkEdge === "function" ? mkEdge() : mkEdge;
      const out = orig(src, tgt, mkEdge, undirected, tag);
      __jacTrackEdge(src, tgt, edge, undirected);
      return out;
    };
  }
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
    if (typeof globalThis.__ospC?.osp_spawn === "function") {
      const result = await globalThis.__ospC.osp_spawn(walkerInst);
      await __jacCommitGraph();
      return result;
    }
    throw new Error("No walker runtime available for Bun host");
  } catch (e) {
    _pendingRows.length = 0;
    throw e;
  }
}
