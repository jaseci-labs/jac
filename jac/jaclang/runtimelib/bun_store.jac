# The Bun-host persistence implementation is plain JavaScript, not this
# language: see bun_store.js in this directory (bundled into service artifacts
# as ./bun_store.js by emit_server_entry, together with the generated
# bun_schema.js carrying SCHEMA_SQL and build-time PROMOTIONS). It implements
# the same Store contract as PgStore, including the byte-identical
# schema_fingerprint stamp protocol from impl/store.impl.jac so bun and
# cpython hosts can share one database without invalidating each other's
# migrations. Keep behavioral changes on both sides in lockstep.
