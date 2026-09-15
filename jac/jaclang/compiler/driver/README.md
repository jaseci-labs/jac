# Analysis ownership

`JacProgram` owns compiler contexts, dependency edges, captured inputs, mutable
compiler caches and the lazily created `AnalysisService`. Separate programs have
separate analysis sessions. The service is synchronous; callers serialize access
to a program. The LSP uses one worker for all compiler access.

- `inputs.jac` captures source buffers, disk reads, missing-file probes,
  configuration, embedded file bytes and annex membership. `InputManifest` is the common freshness
  contract for live modules, interface artifacts and symbol-index shards. Nested
  read scopes record a dependency's own reads without inheriting its importer's
  inputs. Interface artifacts validate imported modules by their public interface
  hashes; their raw-input manifest excludes those module sources and annexes, so
  a dependency body edit does not invalidate every importer. The compiler
  dependency graph records all reads and survives eviction.
  Compiler self-hosting uses its own source store and bytecode input scope, so
  editor overlays and compiler implementation reads stay with their owning program.
- `analysis_service.jac` plans app contexts, requests compiler products, merges
  diagnostics and owns the symbol index and compact analysis records.
- `pipeline.jac` remains the owner of compiler product scheduling and analysis
  facts. The service does not define another pass pipeline.
- The existing JIR format stores interfaces and symbol shards. `SEC_INPUTS`
  records artifact provenance. Unsaved inputs cannot be persisted as disk
  artifacts. Legacy artifacts without provenance require a disk-equivalent view.
- `CodeIntelligence` and the LSP query the same compiler-owned index. Editor
  tokens, outlines and completion presentation stay in the LSP. They retain no
  independent compiler dependency graph or source invalidation policy.

Trees are borrowed within serialized work. Compiler cache trimming may detach
whole contexts; dependency metadata and compact projections survive. An editor
operation requiring a tree requests it again. Incrementality is at module and
app-context granularity; input manifests follow each compilation's read scope.

The LSP queue coalesces file work and bounds queued requests. Foreground bursts
alternate with ready file work, including scanning and indexing. References and
rename capture a work epoch: they wait for that work and scan descendants, while
unrelated later work does not extend their completeness barrier. Cancellation
requeues unfinished file work in its original epoch.
