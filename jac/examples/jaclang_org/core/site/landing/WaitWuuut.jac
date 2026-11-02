glob GROUPS: list[dict[str, any]] = [
         {
             "key": "synechic",
             "pre": "",
             "hot": "Synechic",
             "post": ": one continuous medium",
             "blurb": "One language compiled at every tier. The server, the browser, and native machine code are targets of the same source, and a function is an API because the compiler owns both sides of the wire.",
             "define": "synechic",
             "sections": [
                 {
                     "tag": "rpc, gone",
                     "title": "A function is the API",
                     "body": "Every code window on this page arrives through this function. def:pub on the server is the entire backend story: no route table, no serializer, no hand-written client stub. The browser calls it like a local function and the typed result rides across the wire.",
                     "path": "core/source/files.jac",
                     "needle": "def:pub source_file(path: str)",
                     "hl": 1,
                     "before": 2,
                     "after": 16,

                 },
                 {
                     "tag": "apps, same trick",
                     "title": "One import crosses an app boundary",
                     "body": "The same import that erases the client/server line erases the service line. jac.toml declares this workspace's apps, and core/social_graph.jac is one of them: a file-rooted service app that the web app, the mobile app, and the cli app all consume by importing it. The boundary is structural, so it compiles and type-checks as a cut no matter how it is deployed; the topology is a profile, so it shares one process under jac run and runs as its own process behind the gateway in the fleet. The knowledge service works the same way: it owns one clone of the jac repo, and the docs reader asks it for the docs of earlier release lines. The shared state module below is consumed by both the web and React Native renderers.",
                     "path": "jac.toml",
                     "needle": "[apps.social_graph]",
                     "hl": 3,
                     "before": 2,
                     "after": 8,
                     "path2": "core/jacyac/impl/state.impl.jac",
                     "needle2": "result = root spawn setup_profile(username=stored_username());",
                     "hl2": 1,
                     "before2": 1,
                     "after2": 12,

                 },
                 {
                     "tag": "native codegen",
                     "title": "One import compiles to a game",
                     "body": "The rocket arena on the tech demo page is native code, and nothing about the wire that imports it says so. The compiler knows arena is a native module, so the edge itself decides: the build compiles the game and the three modules behind it to WebAssembly through Jac's own LLVM backend and wasm linker, serves the artifact from /static, and binds each name to a stub that instantiates it on first call. The second window is the payoff: the first call awaits instantiation, and after that init is just a function you call.",
                     "path": "archwire.jac",
                     "needle": "arena ++> webgl_host {",
                     "hl": 1,
                     "before": 1,
                     "after": 4,
                     "path2": "core/site/game/webgl_host.jac",
                     "needle2": "game = await init();",
                     "hl2": 1,
                     "before2": 4,
                     "after2": 4,

                 },
                 {
                     "tag": "http, optional",
                     "title": "curl | bash hits a function",
                     "body": "The install script this site serves is not a file on disk. It is the return value of a typed function, dressed by @restspec with the content type curl expects. When function-as-endpoint is the default, serving a shell script stops being an ops task.",
                     "path": "core/install.jac",
                     "needle": "@restspec(",
                     "hl": 6,
                     "before": 2,
                     "after": 10,

                 },
                 {
                     "define": "substrate",
                     "tag": "inferred client",
                     "title": "The highlighter is Jac too",
                     "body": "The syntax coloring in every window on this page happens in your browser, in Jac. Nothing marks this module as client code, and it lives in core/, outside every app; it compiles to JavaScript because client components import it, the same way the game module compiles to wasm. One language, three targets, decided by the edges of the import graph.",
                     "path": "core/jac_tokenizer.jac",
                     "needle": "def:pub tokenize_lines(",
                     "hl": 1,
                     "before": 3,
                     "after": 12,

                 },

             ],

         },
         {
             "key": "topokinetic",
             "pre": "",
             "hot": "Topokinetic",
             "post": ": computation moves to the data",
             "blurb": "The docs and JacYac are persistent graphs, and the code that serves them travels: walkers descend, fold, and climb the topology instead of querying it from a distance.",
             "define": "topokinetic",
             "sections": [
                 {
                     "define": "osp",
                     "tag": "object-spatial",
                     "title": "The URL walks a graph",
                     "body": "The docs on this site are not files behind a router; they are nodes in a persistent graph. A walker spawns at the root and descends, and because version and directory nodes share a supertype, one polymorphic ability handles every hop. Whatever the walker lands on becomes the response: the URL is a path through the graph, literally.",
                     "path": "core/docs/graph.jac",
                     "needle": "walker:pub doc_page {",
                     "hl": 1,
                     "before": 2,
                     "after": 12,

                 },
                 {
                     "tag": "visit, or else",
                     "title": "Find-or-fallback is a traversal",
                     "body": "Routing a docs URL is not string matching; it is walking. Each path segment tries to step into a directory, else a page, else the section index, and the else branch of a visit runs only when the edges matched nothing. The conditional has moved out of the code and into the topology.",
                     "path": "core/docs/impl/graph.impl.jac",
                     "needle": "[?:DocPage, name==nxt]] else {",
                     "hl": 1,
                     "before": 4,
                     "after": 10,

                 },
                 {
                     "tag": "the else that builds",
                     "title": "Find-or-create is a traversal too",
                     "body": "Ingest places every page by walking its path down from the version node. When a directory on the route does not exist yet, the else of the visit creates it and walks into it, so the tree assembles itself out of the walk. The same statement that routes a reader builds the library.",
                     "path": "core/docs/impl/graph.impl.jac",
                     "needle": "+>:Contains():+> DocDir(name=nxt",
                     "hl": 3,
                     "before": 5,
                     "after": 10,

                 },
                 {
                     "tag": "exit is a phase",
                     "title": "The sidebar is a post-order fold",
                     "body": "The docs sidebar is folded by a walker, not a recursive function. An exit ability fires only after everything reachable from that node has been visited, so by the time a directory folds itself, its children are already folded; the parent just reads them back off the graph. Post-order for free, no stack in sight.",
                     "path": "core/docs/impl/graph.impl.jac",
                     "needle": "impl collect_tree.fold_dir with DocDir exit",
                     "hl": 1,
                     "before": 6,
                     "after": 12,

                 },
                 {
                     "tag": "edges, not fields",
                     "title": "Reading order is a relationship",
                     "body": "Prev and next are not fields kept in sync on every page; they are NextPage edges chained once at build. Reading them back is one hop backward and one hop forward from wherever the walker stands, and a page's URL is not stored anywhere either: it is derived by climbing the Contains edges above it. Delete a page and its place in the order goes with it.",
                     "path": "core/docs/impl/graph.impl.jac",
                     "needle": "[here<-:NextPage:<-[?:DocPage]]",
                     "hl": 2,
                     "before": 3,
                     "after": 12,

                 },
                 {
                     "tag": "dispatch by arrival",
                     "title": "The type switch that walked away",
                     "body": "Deriving a page's URL used to be a function with an isinstance ladder inside. Now it is a walker spawned on the node that climbs the Contains edges upward: the type of wherever it lands picks the ability that runs, and the version node's empty ability is the stop condition, because a walker that does not visit simply halts.",
                     "path": "core/docs/graph.jac",
                     "needle": "walker:protect trace_route {",
                     "hl": 1,
                     "before": 8,
                     "after": 10,

                 },
                 {
                     "tag": "walkers, wired",
                     "title": "root spawn, from the browser",
                     "body": "The docs shell renders a page by spawning that walker on root, from the browser. The spawn crosses the wire as an API call, the walker runs against the persistent graph on the server, and whatever it reports comes back as the return value. One keyword, a full client-to-graph round trip.",
                     "path": "core/site/docs/impl/DocsShell.impl.jac",
                     "needle": "root spawn doc_page",
                     "hl": 1,
                     "before": 4,
                     "after": 8,

                 },
                 {
                     "tag": "persistence, free",
                     "title": "A server call, in passing",
                     "body": "One line inside the navbar keeps the install script fresh: await a server function and move on. Behind it, that function stamps its bookkeeping on root, the persistent graph, so there is no database setup, no ORM, no migration script. State that should outlive a request simply does.",
                     "path": "core/site/ui/impl/Navbar.impl.jac",
                     "needle": "await ensure_install()",
                     "hl": 1,
                     "before": 4,
                     "after": 8,

                 },
                 {
                     "tag": "queries are paths",
                     "title": "The lookup is one expression",
                     "body": "A JacYac feed is one path: from your profile across Follow edges to the profiles you follow, then on to their tweets. The bracketed edge reference is a small query algebra: direction, edge type, node type, field predicate, one expression. Assign it to a variable and it is a query; hand it to visit and it is an itinerary.",
                     "path": "core/social_graph.jac",
                     "needle": "visit [me->:Follow:->[?:Profile]-->[?:Tweet]];",
                     "hl": 1,
                     "before": 2,
                     "after": 6,

                 },

             ],

         },
         {
             "key": "ownership",
             "pre": "",
             "hot": "Gradual ownership",
             "post": ": a dial, not a divide",
             "blurb": "Owned state, borrowed rendering, and typed entity pools in the game you can play here. The same simulation also validates the compiler's zero-RC memory profile.",
             "define": "borrow",
             "sections": [
                 {
                     "tag": "ownership tree",
                     "title": "One owner, all the way down",
                     "body": "Game owns the player, entity pools, event buffers, input state, and random generator. Ownership continues through fields and into list elements, so the compiler knows which parent is responsible for each value. The same simulation is tested under managed, RC, and nogc profiles; this website uses managed memory.",
                     "path": "core/site/game/sim.jac",
                     "needle": "obj Game {",
                     "hl": 12,
                     "before": 0,
                     "after": 3,

                 },
                 {
                     "tag": "borrowed rendering",
                     "title": "A renderer that can only read",
                     "body": "RenderView contains shared borrows of just the fields drawing needs. Each frame finishes its simulation updates, builds this local view, and lends it to the renderer. The view cannot become an independent owner or escape the lifetime of the game it borrows.",
                     "path": "core/site/game/arena.jac",
                     "needle": "obj RenderView {",
                     "hl": 9,
                     "before": 0,
                     "after": 3,

                 },
                 {
                     "tag": "receiver inference",
                     "title": "Methods say what they change",
                     "body": "Player.tick updates the player and takes an exclusive borrow of the command state. The compiler infers the mutating receiver from the method body. At the call site, the player and command are separate fields, so their mutable access can coexist without borrowing unrelated game state.",
                     "path": "core/site/game/impl/sim.impl.jac",
                     "needle": "impl tick_player(w: &mut Game)",
                     "hl": 4,
                     "before": 0,
                     "after": 3,

                 },
                 {
                     "tag": "owned collections",
                     "title": "Remove an entity by moving it",
                     "body": "Enemy, projectile, and spark pools store typed owned records. This generic helper pops the final record and moves it into the removed slot when needed. The container releases the replaced value; the code needs no parallel field arrays or hand-written destructor loop.",
                     "path": "core/site/game/sim.jac",
                     "needle": "def remove_at[T]",
                     "hl": 6,
                     "before": 0,
                     "after": 6,

                 },
                 {
                     "tag": "mutable places",
                     "title": "Two event buffers, one swap",
                     "body": "A tick swaps the pending and processing buffers through explicit mutable borrows of disjoint fields. Processing then reads typed explosion and kill records while building effects. Kill records carry slot generations so a stale event cannot score against a replacement enemy.",
                     "path": "core/site/game/impl/sim.impl.jac",
                     "needle": "impl process_events(w: &mut Game)",
                     "hl": 2,
                     "before": 0,
                     "after": 12,

                 },
                 {
                     "tag": "ownership at the boundary",
                     "title": "Starting returns ownership; stopping consumes it",
                     "body": "The native API returns an owned Game from init and consumes it in shutdown. In the browser, the Wasm boundary represents that game as an integer handle. Stopping uses take to clear the optional handle before calling shutdown, while session checks keep stale callbacks from stopping a replacement game. That host lifecycle is explicit; the integer is not itself an own Game contract.",
                     "path": "core/site/game/arena.jac",
                     "needle": "def init -> own Game;",
                     "hl": 5,
                     "before": 0,
                     "after": 5,
                     "path2": "core/site/game/webgl_host.jac",
                     "needle2": "game = take(sh.game);",
                     "hl2": 4,
                     "before2": 3,
                     "after2": 6,

                 },
                 {
                     "tag": "determinism",
                     "title": "A sim you could replay",
                     "body": "Rendering follows the display while the simulation steps at a fixed 60Hz. The accumulator preserves elapsed time and rendering interpolates between ticks. The simulation owns its seeded random generator and makes no platform calls. Space jumps and left click shoots; input presses remain queued until a simulation tick consumes them.",
                     "path": "core/site/game/impl/arena.impl.jac",
                     "needle": "while w.input.acc >= TICK_DT",
                     "hl": 4,
                     "before": 6,
                     "after": 13,

                 },

             ],

         },
         {
             "key": "craft",
             "pre": "And the rest of the ",
             "hot": "craft",
             "post": "",
             "blurb": "Tests as syntax, interfaces apart from implementations, and a page that can prove all of it by reading itself.",
             "sections": [
                 {
                     "tag": "tests are syntax",
                     "title": "test is a keyword",
                     "body": "That tokenizer ships with its tests in the file next door, written with the language's own test blocks. jac test discovers and runs them; there is no framework to import, no runner to configure, and CI runs the same command you do.",
                     "path": "core/jac_tokenizer.test.jac",
                     "needle": "test \"keywords types and literals are classified\"",
                     "hl": 1,
                     "before": 1,
                     "after": 12,

                 },
                 {
                     "tag": "decl vs impl",
                     "title": "The what and the how, apart",
                     "body": "Any declaration can push its body into an impl file, and this site uses adjacent impl folders where separating the interface makes the code easier to read. The first window is the what: a one-line decl inside the component, ending in a semicolon. The second is the how, living in the impl folder next door. The compiler stitches them back together as one unit.",
                     "path": "core/site/landing/impl/WasmGame.impl.jac",
                     "needle": "def launch(_e: MouseEvent);",
                     "hl": 1,
                     "before": 3,
                     "after": 7,
                     "path2": "core/site/landing/impl/WasmGame.impl.jac",
                     "needle2": "impl WasmGame.launch",
                     "hl2": 1,
                     "before2": 0,
                     "after2": 8,

                 },
                 {
                     "tag": "the-kicker-anchor",
                     "title": "This page, reading itself",
                     "body": "Every section above is one entry in a list at the top of this page's own source, and the page is a loop over that list. This window resolved its own entry: the anchor it searched for is the tag printed beside this paragraph. Wait, wuuut.",
                     "path": "core/site/landing/WaitWuuut.jac",
                     "needle": "\"tag\": \"the-kicker-anchor\"",
                     "hl": 1,
                     "before": 6,
                     "after": 10,

                 },

             ],

         },

     ],
     ABSENT: list[dict[str, any]] = [
         {
             "thing": "a database",
             "why": "The docs and JacYac live in a persistent graph. root outlives every request with no schema, no connection string, no setup."
         },
         {
             "thing": "an ORM or migrations",
             "why": "Nodes and edges are the data model. There is no mapping layer to write and nothing for it to drift out of sync with."
         },
         {
             "thing": "API routes",
             "why": "No router file, no controllers, no handlers. def:pub and spawnable walkers are the endpoints."
         },
         {
             "thing": "fetch or axios",
             "why": "The browser imports server functions and calls them. The compiler writes the wire code on both sides."
         },
         {
             "thing": "serializers or DTOs",
             "why": "Typed objects cross the wire as themselves, in both directions."
         },
         {
             "thing": "an OpenAPI spec",
             "why": "One compiler owns both ends of every call, so there is no contract to publish, version, or drift from."
         },
         {
             "thing": "request validation",
             "why": "The function signature is the schema. Arguments are typed and checked at the boundary."
         },
         {
             "thing": "hand-written JWT signing",
             "why": "Jac handles session tokens and per-user roots. Jac Scale provides the OAuth sessions used by GitHub sign-in."
         },
         {
             "thing": "a package.json",
             "why": "There is no node project to maintain. The toolchain derives the web build from the import graph."
         },
         {
             "thing": "webpack or vite config",
             "why": "Bundling, code splitting, static assets, and the dev server all come out of jac run."
         },
         {
             "thing": "a wasm toolchain",
             "why": "No emscripten, no wasm-pack, no linker scripts. The game compiles to WebAssembly because an import said so."
         },
         {
             "thing": "TypeScript",
             "why": "One type system spans server, browser, and native machine code. Nothing gets redeclared at the edges."
         },
         {
             "thing": "a test framework",
             "why": "test is a keyword and jac test is the runner. There is nothing to install or configure."
         },

     ],
     NAV_ITEMS: list[dict[str, any]] = [
         {"id": "g-absent", "label": "won't see"},
         {"id": "g-synechic", "label": "synechic"},
         {"id": "g-topokinetic", "label": "topokinetic"},
         {"id": "g-ownership", "label": "ownership"},
         {"id": "g-craft", "label": "craft"},
         {"id": "g-lexicon", "label": "lexicon"},

     ],
     DEFS: dict[str, any] = {
         "synechic": {
             "term": "synechic",
             "ipa": "/sɪˈnɛk.ɪk/",
             "pos": "adj.",
             "ety": "from Greek synechēs, continuous, unbroken; cf. Peirce's synechism",
             "body": "The property of a language that presents a single continuous semantic medium across conventionally discrete ecosystems, tiers, and toolchains, with no glue at any crossing.",
             "num": 1
         },
         "substrate": {
             "term": "substrate transparency",
             "ipa": "",
             "pos": "n.",
             "ety": "",
             "body": "The property that the identity of the runtime, ecosystem, and toolchain at any program point has no bearing on how the program is expressed.",
             "num": 2
         },
         "topokinetic": {
             "term": "topokinetic",
             "ipa": "/ˌtoʊ.poʊ.kɪˈnɛt.ɪk/",
             "pos": "adj.",
             "ety": "from Greek topos, place, and kinēsis, motion",
             "body": "The property of a language in which the mobile locus of computation over a topology of data is a first-class semantic construct, inverting the convention of streaming data to a fixed site of compute.",
             "num": 3
         },
         "osp": {
             "term": "Object-Spatial Programming (OSP)",
             "ipa": "",
             "pos": "n.",
             "ety": "",
             "body": "The paradigm realizing topokinesis: programs expressed as walkers traversing a persistent topology of nodes and edges, with abilities triggered by arrival.",
             "num": 4
         },
         "borrow": {
             "term": "gradual borrow checking",
             "ipa": "",
             "pos": "n.",
             "ety": "",
             "body": "Memory discipline as a continuum within one language: managed semantics by default, ownership adoptable one declaration at a time, and a checked boundary mediating every crossing between the regimes.",
             "num": 5
         }
     },
     LEX_ORDER: list[str] = ["synechic", "substrate", "topokinetic", "osp", "borrow"];

def Definition(
    term: str, pos: str, body: str, ipa: str = "", ety: str = "", num: int = 0
) -> JsxElement;

def DefCard(k: str) -> JsxElement;

def LexiconSection -> JsxElement;

def AbsentSection -> JsxElement;

def GroupHeader(pre: str, hot: str, post: str, blurb: str) -> JsxElement;

def FeatureSection(idx: int, data: dict[str, any], on_pop: any) -> JsxElement;

def:pub WaitWuuut -> JsxElement;
