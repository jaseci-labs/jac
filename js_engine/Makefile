BIN           := bin/js_engine
MAIN          := engine/src/main.jac
# The jac used for native builds; override with e.g. `make JAC=/path/to/jac`.
JAC           ?= jac
# Engine-compile stats ("%e %M" = elapsed seconds, max RSS KB), written by the
# $(BIN)/scrub-engine rules and consumed (printed + removed) at the end of
# build/scrub. Lives under bin/ so `make clean` removes it.
BUILD_STATS   := bin/.build_stats
# O3 measured +3-6% engine-wide vs O2 (issues/jac-native-inlining-gaps);
# override with JAC_OPT_LEVEL=n if compile time matters more than speed.
export JAC_OPT_LEVEL ?= 3
# Link C libraries as shared libraries, not from jac's static "floor" archives.
# The floor links libssl.a without the libcrypto.a members it depends on and
# drops both from DT_NEEDED, so the engine dies at startup with
# `undefined symbol: OSSL_STORE_open`. An empty floor dir turns the floor off.
# Remove once the native linker resolves floor archives across each other.
NO_FLOOR_DIR  := bin/.no-floor
export JAC_NATIVE_FLOOR_DIR ?= $(abspath $(NO_FLOOR_DIR))
SOURCES       := $(shell find engine/src/ napi/src/ -name '*.jac' 2>/dev/null)

# ── Precompiled builtin bytecode (.jsbc) — see docs/jsbc_bytecode_cache_plan.md ─
# NOTE: recursive — builtins live in subdirs too (e.g. fs/promises.js). Every
# builtins/js/**/*.js compiles to a sibling .jsbc; those are intermediates joined
# into BUILTIN_PACK, the one bytecode file the engine loads (keyed by path under
# builtins/js/, see the runtime's `_builtin_key_for`). Sorted so the pack is
# byte-identical whatever order `find` returns.
JSC           := bin/js_compiler
JSC_MAIN      := engine/src/js_compiler.jac
BUILTIN_JS    := $(sort $(shell find engine/src/builtins/js -name '*.js' 2>/dev/null))
BUILTIN_JSBC  := $(BUILTIN_JS:.js=.jsbc)
BUILTIN_PACK  := engine/src/builtins/builtins.jsbc
BIN_PACK      := bin/builtins.jsbc
NAPI_SHIM_SRC := napi/shim/napi_shim.c
NAPI_SHIM_VER := napi/shim/napi.ver
NAPI_SHIM_SO  := lib/libnapi_shim.so
NAPI_INC      := /usr/include/node

TZ_SHIM_SRC   := native/tz_shim/tz_shim.c
TZ_SHIM_VER   := native/tz_shim/tz.ver
TZ_SHIM_SO    := lib/libtz_shim.so
TZ_SHIM_INC   := native/tz_shim
TZDATA_DIR    := share/tzdata

ICU_SHIM_SRC  := native/icu_shim/icu_shim.c
ICU_SHIM_VER  := native/icu_shim/icu.ver
ICU_SHIM_SO   := lib/libicu_shim.so
ICU_SHIM_INC  := native/icu_shim

# ── PCRE2 10.45 dependency ───────────────────────────────────────────────────
PCRE2_VERSION  := 10.45
# Auto-detect the PCRE2 shared object across distros (Debian/Ubuntu multiarch,
# Arch /usr/lib, Fedora /usr/lib64); fall back to the Ubuntu path so
# `make install_deps` still knows where to put a source-built copy.
PCRE2_SO       := $(shell for p in /usr/lib/x86_64-linux-gnu/libpcre2-8.so.0 /usr/lib/libpcre2-8.so.0 /usr/lib64/libpcre2-8.so.0; do [ -e "$$p" ] && echo "$$p" && exit 0; done; echo /usr/lib/x86_64-linux-gnu/libpcre2-8.so.0)
PCRE2_URL      := https://github.com/PCRE2Project/pcre2/releases/download/pcre2-$(PCRE2_VERSION)/pcre2-$(PCRE2_VERSION).tar.gz
PCRE2_TARBALL  := /tmp/pcre2-$(PCRE2_VERSION).tar.gz
PCRE2_BUILDDIR := /tmp/pcre2-$(PCRE2_VERSION)
PCRE2_INSTDIR  := /tmp/pcre2-inst-$(PCRE2_VERSION)

# ── Wasmtime 48.0.2 C API dependency (WebAssembly engine) ────────────────────
# Vendored Bytecode Alliance Wasmtime C API release. libwasmtime.so lives
# directly in lib/ next to the other shims (it carries no SONAME, so its
# DT_NEEDED is the literal import path lib/libwasmtime.so, rewritten to the bare
# soname libwasmtime.so by tools/fix_engine_needed.jac). Headers are vendored
# under lib/wasmtime/include/ for reference (jac FFI signatures live in
# engine/src/ffi/wasmtime.jac). See docs/wasm.md Phase 0.
WASMTIME_VERSION  := 48.0.2
WASMTIME_SO       := lib/libwasmtime.so
WASMTIME_INCDIR   := lib/wasmtime/include
WASMTIME_SHA256   := d9a2b5dfaf688035f288a7ae81a4b96c3acdd3e849262c2ab577b61908c3f9f9
WASMTIME_ARCHIVE  := wasmtime-v$(WASMTIME_VERSION)-x86_64-linux-c-api
WASMTIME_URL      := https://github.com/bytecodealliance/wasmtime/releases/download/v$(WASMTIME_VERSION)/$(WASMTIME_ARCHIVE).tar.xz
WASMTIME_TARBALL  := /tmp/$(WASMTIME_ARCHIVE).tar.xz
WASMTIME_SRCDIR   := /tmp/$(WASMTIME_ARCHIVE)

# ── llhttp 9.4.1 dependency ──────────────────────────────────────────────────
LLHTTP_VERSION  := 9.4.1
LLHTTP_SO       := lib/llhttp/lib/libllhttp.so
LLHTTP_URL      := https://github.com/nodejs/llhttp/archive/refs/tags/release/v$(LLHTTP_VERSION).tar.gz
LLHTTP_TARBALL  := /tmp/llhttp-$(LLHTTP_VERSION).tar.gz
LLHTTP_SRCDIR   := /tmp/llhttp-release-v$(LLHTTP_VERSION)
LLHTTP_BUILDDIR := /tmp/llhttp-build-$(LLHTTP_VERSION)
LLHTTP_INSTDIR  := $(CURDIR)/lib/llhttp

.PHONY: all build scrub scrub-engine clean run dist test_language test_builtins napi_shim tz_shim icu_shim tzdata wasmtime install_deps js_compiler builtins-bytecode check-bytecode js_engine_select pm-resources check-pm-resources

# ── Default (incremental build) ──────────────────────────────────────────────
all: build

# ── js_engine_select helper ──────────────────────────────────────────────────
# Install the recency-selector wrapper into bin/ if it isn't there yet (never
# overwrites a local copy). It runs archived builds (bin/js_engine.<date>) by
# recency: `bin/js_engine_select -1 --gc app.mjs` runs the latest archive,
# `-2` the one before it, `-0` the current live build.
js_engine_select:
	@mkdir -p bin
	@if [ ! -e bin/js_engine_select ]; then \
	    cp tools/js_engine_select.sh bin/js_engine_select && chmod +x bin/js_engine_select && \
	    echo "Installed bin/js_engine_select"; \
	fi

# ── Build (incremental — reuses cached IR for unchanged modules) ─────────────
# Runs install_deps first (it skips every dependency that is already present).
# Also (re)generates the builtin bytecode pack. It is a build artifact (not
# committed — see .gitignore `*jsbc`); the engine loads it for speed and parses
# the builtin .js only when there is no pack.
build: install_deps $(NAPI_SHIM_SO) $(TZ_SHIM_SO) $(ICU_SHIM_SO) $(WASMTIME_SO) $(BIN) builtins-bytecode js_engine_select
	$(call print_build_stats)

# Print engine-compile stats recorded by the $(BIN)/scrub-engine rules. The
# stats file is consumed so an incremental rebuild that skips the engine
# compile doesn't reprint stale numbers.
define print_build_stats
	@if [ -f $(BUILD_STATS) ]; then \
	    read secs kb < $(BUILD_STATS); rm -f $(BUILD_STATS); \
	    printf "==> Build stats: engine compile time %ss | peak memory %s MB\n" \
	        "$$secs" "$$((kb / 1024))"; \
	else \
	    printf "==> Build stats: engine not recompiled (IR cache up to date)\n"; \
	fi
endef

$(NAPI_SHIM_SO): $(NAPI_SHIM_SRC) $(NAPI_SHIM_VER)
	@mkdir -p lib
	cc -shared -fPIC -I$(NAPI_INC) -I/usr/include \
	    -Wl,--version-script=$(NAPI_SHIM_VER) \
	    -o $@ $(NAPI_SHIM_SRC) -lpthread
	@echo "Built: $@"

napi_shim: $(NAPI_SHIM_SO)

$(TZDATA_DIR)/UTC:
	@bash tools/update_tzdata.sh --minimal

$(TZ_SHIM_SO): $(TZ_SHIM_SRC) $(TZ_SHIM_VER) $(TZDATA_DIR)/UTC
	@mkdir -p lib
	cc -shared -fPIC -I$(TZ_SHIM_INC) \
	    -DTZDATA_SHARE_PATH='"$(CURDIR)/$(TZDATA_DIR)"' \
	    -Wl,--version-script=$(TZ_SHIM_VER) \
	    -o $@ $(TZ_SHIM_SRC)
	@echo "Built: $@"

tz_shim: $(TZ_SHIM_SO)

$(ICU_SHIM_SO): $(ICU_SHIM_SRC) $(ICU_SHIM_VER)
	@mkdir -p lib
	cc -shared -fPIC -I$(ICU_SHIM_INC) \
	    -Wl,--version-script=$(ICU_SHIM_VER) \
	    -o $@ $(ICU_SHIM_SRC) -licuuc -licui18n -licudata
	@echo "Built: $@"

icu_shim: $(ICU_SHIM_SO)

# ── Vendored Wasmtime C API ──────────────────────────────────────────────────
# Fetch + checksum-verify the pinned release tarball, then extract the full
# (non-minimal) libwasmtime.so into lib/ and the headers into lib/wasmtime/.
# The .so is committed alongside the other shims; this rule only fires if it is
# missing (fresh checkout / after `make clean`).
$(WASMTIME_SO):
	@mkdir -p lib $(WASMTIME_INCDIR)
	@if [ ! -f $(WASMTIME_TARBALL) ]; then \
		echo "Fetching Wasmtime $(WASMTIME_VERSION) C API..."; \
		wget -q --show-progress -O $(WASMTIME_TARBALL) $(WASMTIME_URL) || \
		curl -L -o $(WASMTIME_TARBALL) $(WASMTIME_URL); \
	fi
	@echo "$(WASMTIME_SHA256)  $(WASMTIME_TARBALL)" | sha256sum -c - \
		|| { echo "wasmtime: checksum mismatch — refusing to install"; exit 1; }
	@rm -rf $(WASMTIME_SRCDIR)
	@tar -xf $(WASMTIME_TARBALL) -C /tmp
	@cp $(WASMTIME_SRCDIR)/lib/libwasmtime.so $(WASMTIME_SO)
	@chmod +x $(WASMTIME_SO)
	@cp -r $(WASMTIME_SRCDIR)/include/. $(WASMTIME_INCDIR)/
	@cp $(WASMTIME_SRCDIR)/LICENSE lib/wasmtime/LICENSE
	@echo "Vendored: $(WASMTIME_SO) (Wasmtime $(WASMTIME_VERSION))"

wasmtime: $(WASMTIME_SO)

tzdata: $(TZDATA_DIR)/UTC

# Jac embeds relative DT_NEEDED entries (lib/libnapi_shim.so, …) which the
# dynamic linker resolves against *cwd*.  Post-link rewrite those strings to
# bare sonames (tools/fix_engine_needed.jac) so LD_LIBRARY_PATH / the test
# harness / child_process.js can locate them regardless of cwd.  Avoid a
# shell-wrapper launcher: nested bash under RLIMIT_AS caused SIGSEGVs in
# spawn-heavy es-module tests.
define fix_engine_libs
	@jac tools/fix_engine_needed.jac $(1)
	@chmod +x $(1)
	@echo "DT_NEEDED sonames fixed: $(1)"
	@# The linker emits DT_RUNPATH=$$ORIGIN (and the ELF has no section headers,
	@# so patchelf cannot widen it): link the shims into bin/ so the binary runs
	@# without LD_LIBRARY_PATH from any cwd — what `JS_ENGINE=bin/js_engine` needs.
	@d=$$(dirname $(1)); for so in libnapi_shim.so libtz_shim.so libicu_shim.so libwasmtime.so; do \
		[ -e lib/$$so ] && ln -sfn ../lib/$$so $$d/$$so; done; \
	[ -e lib/llhttp/lib/libllhttp.so ] && ln -sfn ../lib/llhttp/lib/libllhttp.so $$d/libllhttp.so; \
	echo "Shim libraries linked into $$d/ (\$$ORIGIN): $(1) runs without LD_LIBRARY_PATH"
endef

# Archive the previous binary as js_engine.<mtime> (its build time) before
# overwriting, so bin/ keeps a history of old builds. Keeps the newest 10
# archives to bound disk use.
define archive_old_bin
	@if [ -f $(1) ]; then \
		ts=$$(date -r $(1) +%Y%m%d-%H%M%S); \
		if [ ! -e $(1).$$ts ]; then cp -p $(1) $(1).$$ts; echo "Archived old build: $(1).$$ts"; fi; \
		ls -1t $(1).* 2>/dev/null | tail -n +11 | xargs -r rm -f; \
	fi
endef

# ── Package-manager resources (compiled into the engine) ─────────────────────
# pm/help/*.txt (bun's help output, verbatim) and pm/data/default-trusted.txt
# are the source of truth; tools/gen_pm_resources.jac turns them into the
# committed pm/resources_gen.jac, so the binary reads no resource files and runs
# from anywhere. Regenerated here whenever a text changes (the touch settles the
# timestamp when the content was already current); `make check-pm-resources`
# fails if the committed module is stale.
PM_RESOURCE_SRCS := $(wildcard engine/src/pm/help/*.txt) engine/src/pm/data/default-trusted.txt
PM_RESOURCES_GEN := engine/src/pm/resources_gen.jac
$(PM_RESOURCES_GEN): $(PM_RESOURCE_SRCS) tools/gen_pm_resources.jac
	$(JAC) tools/gen_pm_resources.jac $@
	@touch $@

pm-resources: $(PM_RESOURCES_GEN)

check-pm-resources:
	@tmp=$$(mktemp); \
	$(JAC) tools/gen_pm_resources.jac $$tmp >/dev/null; \
	if cmp -s $$tmp $(PM_RESOURCES_GEN); then rc=0; \
	    echo "check-pm-resources: $(PM_RESOURCES_GEN) matches the .txt sources"; \
	else rc=1; echo "STALE: $(PM_RESOURCES_GEN) differs — run 'make pm-resources'"; fi; \
	rm -f $$tmp; exit $$rc

# install_deps is order-only: it runs before the link (also under -j) but never
# forces a relink by itself.
$(BIN): $(SOURCES) $(PM_RESOURCES_GEN) | install_deps
	@mkdir -p bin $(NO_FLOOR_DIR)
	$(call archive_old_bin,$(BIN))
	/usr/bin/time -f "%e %M" -o $(BUILD_STATS) $(JAC) build --native $(MAIN) -o $(BIN)
	$(call fix_engine_libs,$(BIN))
	@echo "Built: $(BIN)"

# ── Scrub build (`jac clean --cache`, then recompile from scratch) ───────────
# `jac clean --cache` wipes the project's whole .jac/cache, so the engine and,
# if it needs rebuilding, the js_compiler tool compile from scratch. Order
# (serial): engine first, then the js_compiler tool, then the builtin .jsbc
# regenerated with it — so a scrub still picks up edits to builtins/js/*.js.
scrub: install_deps $(NAPI_SHIM_SO) $(TZ_SHIM_SO) $(ICU_SHIM_SO) $(WASMTIME_SO) scrub-engine builtins-bytecode
	@echo "Built: $(BIN) (scrub build)"
	$(call print_build_stats)

# Scrub-compile the engine. Ordered first so js_engine is built before the
# js_compiler tool and the builtin bytecode.
# With JAC_SYMMAP set, the old binary and its link record go too: jac reuses a
# link whose record (bin/js_engine.layout.json, which `jac clean --cache` does
# not touch) still matches, and a reused link writes no bin/js_engine.symmap.
# It compiles the engine itself, so it regenerates the pm resources first, as
# $(BIN) does.
scrub-engine: install_deps $(NAPI_SHIM_SO) $(TZ_SHIM_SO) $(ICU_SHIM_SO) $(WASMTIME_SO) $(PM_RESOURCES_GEN)
	@mkdir -p bin $(NO_FLOOR_DIR)
	$(call archive_old_bin,$(BIN))
	$(if $(JAC_SYMMAP),rm -f $(BIN) $(BIN).layout.json $(BIN).symmap)
	$(JAC) clean --cache --force
	/usr/bin/time -f "%e %M" -o $(BUILD_STATS) $(JAC) build --native $(MAIN) -o $(BIN)
	$(call fix_engine_libs,$(BIN))

# ── Precompiled builtin bytecode (.jsbc) ─────────────────────────────────────
# js_compiler is a thin build-time tool (no event loop). It compiles each builtin
# *.js to a sibling *.jsbc. The committed .jsbc are the shipped artifacts; the
# engine loads them and never compiles builtin JS at runtime (see the plan doc).
$(JSC): $(SOURCES) | install_deps
	@mkdir -p bin $(NO_FLOOR_DIR)
	$(JAC) build --native $(JSC_MAIN) -o $(JSC)
	@echo "Built: $(JSC)"

js_compiler: $(JSC)

# Pattern rule: compile a builtin .js to its sibling .jsbc via js_compiler.
# LD_LIBRARY_PATH mirrors how the engine is run (shims live in lib/). Per-file
# js_compiler output is suppressed; the recompiled basename is echoed instead.
engine/src/builtins/js/%.jsbc: engine/src/builtins/js/%.js $(JSC)
	@LD_LIBRARY_PATH="$(CURDIR)/lib:$(CURDIR)/lib/llhttp/lib:$$LD_LIBRARY_PATH" \
	    $(JSC) $< $@ >/dev/null
	@echo "  recompiled $(<:engine/src/builtins/js/%=%)"

# Join every builtin's .jsbc into the single pack the engine loads.
$(BUILTIN_PACK): $(BUILTIN_JSBC) $(JSC)
	@LD_LIBRARY_PATH="$(CURDIR)/lib:$(CURDIR)/lib/llhttp/lib:$$LD_LIBRARY_PATH" \
	    $(JSC) --pack $@ $(BUILTIN_JSBC) >/dev/null
	@echo "  packed $(words $(BUILTIN_JSBC)) modules into $@"

# A copy next to the binary — where the engine looks for the pack first.
$(BIN_PACK): $(BUILTIN_PACK)
	@mkdir -p bin
	@cp $< $@
	@echo "  copied $< to $@"

# Regenerate every builtin's .jsbc (only stale ones recompile) and the pack.
# Run this after editing any builtins/js/*.js.
builtins-bytecode: $(JSC) $(BUILTIN_JSBC) $(BUILTIN_PACK) $(BIN_PACK)
	@echo "builtins-bytecode: $(words $(BUILTIN_JSBC)) .jsbc + $(BUILTIN_PACK) ($(BIN_PACK)) up to date"

# CI guard: recompile all builtins to a temp dir and diff against the committed
# .jsbc, then re-pack and diff against the pack — fails if a .js was edited
# without regenerating (enforces the dev duty).
check-bytecode: $(JSC)
	@set -e; tmp=$$(mktemp -d); rc=0; \
	export LD_LIBRARY_PATH="$(CURDIR)/lib:$(CURDIR)/lib/llhttp/lib:$$LD_LIBRARY_PATH"; \
	for js in $(BUILTIN_JS); do \
	    committed=$${js%.js}.jsbc; \
	    $(JSC) $$js $$tmp/out.jsbc >/dev/null; \
	    if ! cmp -s $$tmp/out.jsbc $$committed; then \
	        echo "STALE: $$committed differs — run 'make builtins-bytecode'"; rc=1; \
	    fi; \
	done; \
	$(JSC) --pack $$tmp/pack.jsbc $(BUILTIN_JSBC) >/dev/null || rc=1; \
	if ! cmp -s $$tmp/pack.jsbc $(BUILTIN_PACK); then \
	    echo "STALE: $(BUILTIN_PACK) differs — run 'make builtins-bytecode'"; rc=1; \
	fi; \
	rm -rf $$tmp; \
	if [ $$rc -eq 0 ]; then echo "check-bytecode: all $(words $(BUILTIN_JS)) .jsbc and the pack match"; fi; \
	exit $$rc

# ── Run a JS file (usage: make run FILE=path/to/script.js) ────────────────────
run: $(BIN)
	$(BIN) $(FILE)

# ── test262 conformance (engine/tests/test262) ──────────────────────────────
# Runs one test262 directory against bin/js_engine and fails on any test that
# passes in its saved baseline but not now (newly passing tests are reported).
# Needs the test262 checkout in engine/tests/test262/vendor:
#   git clone --depth 1 https://github.com/tc39/test262 engine/tests/test262/vendor
# Extra runner flags via T262_ARGS, e.g. T262_ARGS="--jobs 4 -v", or
# T262_ARGS="--save-baseline engine/tests/test262/language_baseline.json".
T262      := engine/tests/test262
T262_ARGS ?=
define run_test262
	@test -d $(T262)/vendor/test || { \
	    echo "test262 checkout missing: git clone --depth 1 https://github.com/tc39/test262 $(T262)/vendor"; \
	    exit 1; }
	jac $(T262)/run_test262.jac --gc --filter $(1) --check-baseline $(T262)/$(2) $(T262_ARGS)
endef

test_language: $(BIN) $(BIN_PACK)
	$(call run_test262,language,language_baseline.json)

test_builtins: $(BIN) $(BIN_PACK)
	$(call run_test262,built-ins,builtins_baseline.json)

# ── Relocatable runtime tree (what the jac binary bundles) ───────────────────
# Everything sits in bin/: the engine finds its builtins next to itself
# (bin/builtins.jsbc — bytecode only, no builtin .js) and its shims through
# $$ORIGIN, so this tree runs from anywhere. That includes PCRE2: distros ship
# releases older than 10.45 (no variable-length lookbehind), and $$ORIGIN puts
# the copy here ahead of the system's, so the tree needs only the stock
# libraries (libuv, OpenSSL, zlib, nghttp2, brotli, zstd, ICU).
# `zig build -Djs-engine=../js_engine/dist` packs it into the jac payload.
DIST := dist
dist: build
	rm -rf $(DIST)
	mkdir -p $(DIST)/bin
	cp $(BIN) $(DIST)/bin/
	cp -L $(NAPI_SHIM_SO) $(TZ_SHIM_SO) $(ICU_SHIM_SO) $(WASMTIME_SO) $(LLHTTP_SO) $(PCRE2_SO) $(DIST)/bin/
	cp $(BUILTIN_PACK) $(DIST)/bin/
	@echo "Staged: $(DIST)/"

# ── Clean ─────────────────────────────────────────────────────────────────────
clean:
	rm -rf bin lib $(DIST)
	find . -type d -name '.jac_ir' -exec rm -rf {} + 2>/dev/null || true

# ── Install system dependencies ───────────────────────────────────────────────
# Ensures PCRE2 10.45+ is installed at $(PCRE2_SO) so that variable-length
# lookbehind assertions compile.  Builds from source if the symbol
# pcre2_set_max_varlookbehind_8 is missing from the current system library.
# Requires sudo to copy into $(dir $(PCRE2_SO)) (portable across distros).
# `make` / `make build` / `make scrub` run this first; each dependency is only
# built when missing, so on an installed machine it just reports and moves on.
install_deps: $(WASMTIME_SO)
	@if nm -D $(PCRE2_SO) 2>/dev/null | grep -q pcre2_set_max_varlookbehind_8; then \
		echo "PCRE2 $(PCRE2_VERSION)+ already installed at $(PCRE2_SO)."; \
	else \
		echo "PCRE2 $(PCRE2_VERSION) not found — building from source..."; \
		if [ ! -f $(PCRE2_TARBALL) ]; then \
			wget -q --show-progress -O $(PCRE2_TARBALL) $(PCRE2_URL) || \
			curl -L -o $(PCRE2_TARBALL) $(PCRE2_URL); \
		fi; \
		rm -rf $(PCRE2_BUILDDIR) $(PCRE2_INSTDIR); \
		tar -xf $(PCRE2_TARBALL) -C /tmp; \
		cd $(PCRE2_BUILDDIR) && \
		./configure --prefix=$(PCRE2_INSTDIR) \
		    --enable-shared --disable-static \
		    --disable-pcre2-16 --disable-pcre2-32 \
		    --enable-jit=no -q && \
		make -j$$(nproc) -s && \
		make install -s; \
		NEWSO=$$(ls $(PCRE2_INSTDIR)/lib/libpcre2-8.so.0.*.*); \
		NEWSO_NAME=$$(basename $$NEWSO); \
		PCRE2_DESTDIR=$$(dirname "$(PCRE2_SO)"); \
		echo "Installing $$NEWSO_NAME to $$PCRE2_DESTDIR/ (requires sudo)..."; \
		sudo mkdir -p "$$PCRE2_DESTDIR"; \
		sudo cp "$$NEWSO" "$$PCRE2_DESTDIR/"; \
		sudo ln -sf "$$NEWSO_NAME" $(PCRE2_SO); \
		sudo ldconfig; \
		echo "PCRE2 $(PCRE2_VERSION) installed successfully."; \
	fi
	@if [ -f $(LLHTTP_SO) ]; then \
		echo "llhttp $(LLHTTP_VERSION) already installed at $(LLHTTP_SO)."; \
	else \
		echo "llhttp $(LLHTTP_VERSION) not found — building from source into lib/llhttp/ ..."; \
		if [ ! -f $(LLHTTP_TARBALL) ]; then \
			wget -q --show-progress -O $(LLHTTP_TARBALL) $(LLHTTP_URL) || \
			curl -L -o $(LLHTTP_TARBALL) $(LLHTTP_URL); \
		fi; \
		rm -rf $(LLHTTP_SRCDIR) $(LLHTTP_BUILDDIR) $(LLHTTP_INSTDIR); \
		tar -xf $(LLHTTP_TARBALL) -C /tmp; \
		mkdir -p $(LLHTTP_BUILDDIR) $(LLHTTP_INSTDIR); \
		cmake -S $(LLHTTP_SRCDIR) -B $(LLHTTP_BUILDDIR) \
		    -DCMAKE_INSTALL_PREFIX=$(LLHTTP_INSTDIR) \
		    -DBUILD_SHARED_LIBS=ON \
		    -DCMAKE_BUILD_TYPE=Release \
		    -DLLHTTP_BUILD_TESTS=OFF \
		    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
		    -Wno-dev 2>&1 | tail -3; \
		cmake --build $(LLHTTP_BUILDDIR) -j$$(nproc) 2>&1 | tail -3; \
		cmake --install $(LLHTTP_BUILDDIR) 2>&1 | tail -5; \
		echo "llhttp $(LLHTTP_VERSION) installed at $(LLHTTP_INSTDIR)"; \
	fi

# ── Help ──────────────────────────────────────────────────────────────────────
help:
	@echo "Targets:"
	@echo "  install_deps     Build and install PCRE2 $(PCRE2_VERSION) to system + llhttp $(LLHTTP_VERSION) to lib/llhttp/ (no sudo needed for llhttp); skips what is installed"
	@echo "  build            Compile main.jac → bin/js_engine  (incremental; runs install_deps first)"
	@echo "  scrub            Full recompile from scratch (jac clean --cache, then build)"
	@echo "  run FILE=<path>  Run a JS file with the compiled engine"
	@echo "  dist             Stage a relocatable runtime tree in dist/ (what the jac binary bundles)"
	@echo "  pm-resources     Regenerate engine/src/pm/resources_gen.jac from pm/help/*.txt + pm/data/*.txt"
	@echo "  check-pm-resources  Fail if the committed pm/resources_gen.jac is stale"
	@echo "  test_language    Run test262 language/ tests; fail on regressions vs language_baseline.json"
	@echo "  test_builtins    Run test262 built-ins/ tests; fail on regressions vs builtins_baseline.json"
	@echo "  napi_shim        Build lib/libnapi_shim.so (NAPI ABI surface)"
	@echo "  tz_shim          Build lib/libtz_shim.so (IANA TZif timezone shim)"
	@echo "  icu_shim         Build lib/libicu_shim.so (ICU Intl shim)"
	@echo "  wasmtime         Fetch + verify vendored Wasmtime $(WASMTIME_VERSION) C API into lib/libwasmtime.so"
	@echo "  tzdata           Vendor minimal IANA zone files into share/tzdata/"
	@echo "  clean            Remove bin/ lib/ and all .jac_ir/ caches"