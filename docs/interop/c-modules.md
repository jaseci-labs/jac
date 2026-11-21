---
description: C and C++ source compiled into a Jac program as a module - the cmodule.toml manifest and its keys, what Jac binds from the headers, wiring C modules together, inline modules, C++ sources, and what goes wrong.
keywords: C module, cmodule.toml, {lib}, {platform}, {dir}, whole archive, inline C module, C++ module, C interface
---
# C modules

A directory holding a `cmodule.toml` is a C module: C (or C++) source that a program compiles with
it and imports as it imports a Jac module. In a project (a directory with a `jac.toml`) the manifest
is a table of `jac.toml`, `[c."<directory>"]`, which jac writes as that file: `jac absorb
<directory>` takes an existing one in ([Packages](../toolchain/packages.md#rust-crates-and-c-modules)). Clang, inside jac, reads the module's headers, so the
program binds what they declare without writing declarations of its own, and compiles its sources
into the program. To call a library that is already built, declare its functions instead: see
[C libraries](c-libraries.md) (`jac docs C library`).

A C module is one of two things, by who holds its manifest:

| | The project's own | A dependency |
|---|---|---|
| Its manifest | A table of `jac.toml`, `[c."<directory>"]` | A `cmodule.toml` in its directory that `jac.toml` does not hold: a vendored library, a loose module beside a program with no `jac.toml` |
| Its interface | What its own files declare: every header in its directory, and each function and variable its C sources define, whether a header declares it or not. It has no `headers` key (E5158) | The headers its `headers` key lists |
| Under an `archwire.jac` | Its files are modules, and a wire names the file that defines what it brings ([below](#wiring-c-modules)) | One module, whole |

## The shortest example

A program with a C module `geom`, a directory beside `main.jac`. It needs no `jac.toml`: a loose
`main.jac` builds with the module beside it, as a project's does.

`geom/cmodule.toml`:

```toml
headers = ["geom.h"]
sources = ["geom.c"]
libs = ["m"]
```

`geom/geom.h`:

```c
#include <stdint.h>

#define GEOM_VERSION 2

typedef enum { SHAPE_SQUARE = 1, SHAPE_CIRCLE = 2 } shape_kind;

typedef struct {
    double x;
    double y;
} point;

typedef struct polygon polygon;

extern int64_t points_made;

point point_new(double x, double y);
double point_length(const point *p);
const char *shape_name(int32_t kind);
int64_t geom_sum(int32_t n, ...);
int64_t geom_fold(int64_t start, int32_t times, int64_t (*step)(int64_t, int64_t));
polygon *polygon_new(void);
void polygon_add(polygon *poly, point p);
double polygon_perimeter(const polygon *poly);
void polygon_free(polygon *poly);
```

`geom/geom.c` defines them. `main.jac`, beside `geom/`:

<!-- example: not checked: needs the C module geom beside the program -->
```jac
import from geom {
    GEOM_VERSION,
    SHAPE_CIRCLE,
    geom_fold,
    geom_sum,
    point,
    point_length,
    point_new,
    points_made,
    polygon,
    polygon_add,
    polygon_free,
    polygon_new,
    polygon_perimeter,
    shape_name,
}

def add(acc: int, i: int) -> int {
    return acc + i;
}

def square(side: float) -> ptr[polygon] {
    poly = polygon_new();
    polygon_add(poly, point(x=0.0, y=0.0));
    polygon_add(poly, point(x=side, y=0.0));
    polygon_add(poly, point_new(side, side));
    polygon_add(poly, point_new(0.0, side));
    return poly;
}

with entry {
    p = point_new(3.0, 4.0);
    print(GEOM_VERSION, p.x, point_length(&p), shape_name(i32(SHAPE_CIRCLE)));
    print(geom_sum(i32(3), 10, 20, 12), geom_fold(100, i32(4), add));
    sq = square(2.5);
    print(polygon_perimeter(sq), points_made);
    polygon_free(sq);
}
```

```sh
jac build main.jac -o main && ./main
```

```text
2 3.0 5.0 circle
42 106
10.0 3
```

`import geom;` works too, and the names are then `geom.point_new` and so on. A C module is found as
any import's module is: by its dotted path from the importing file's directory or the project's
root (`import from vendor.zlib { ... }` for `vendor/zlib/cmodule.toml`).

## What Jac binds from the headers

Clang reads the headers for the program's target. What they declare in files under the module's
directory, and under the directory of each header they name outside it (a library's installed
API, such as Node-API's `node_api.h`), becomes Jac declarations, in the types a
[C library](c-libraries.md#types-in-a-declaration) declaration takes. Declarations of the system's
headers (`<stdio.h>`, `<stdint.h>`) are not part of the module.

| C | Jac |
|---|---|
| A function | A function; a variadic one takes extra arguments as `*args` does |
| `int32_t`, `int` | `i32`; `int64_t`, `long long` are `int`, the other integer types their sized type |
| `double`, `float` | `float`, `f32` |
| `const char *` parameter | `str \| bytes \| bytearray \| None`: the text, the bytes of a buffer, or `NULL` |
| `const char *` result | `str \| None`, `None` for `NULL` |
| `char *` | `ptr[i8]`, whatever the target's `char` signedness |
| Any other pointer `T *` | `ptr[T]`; a parameter also takes `&x` or `&mut x` of a `T` variable, its address for the call |
| A pointer to a function | `Callable[[P, ...], R] \| None`, which a named Jac function is passed as, or `None` for `NULL` |
| A `struct` | A record, constructed by keyword (`point(x=1.0, y=2.0)`, fields left out are zero), passed and returned by value |
| A `struct` declared but not defined (`typedef struct polygon polygon;`) | An opaque type, held as `ptr[polygon]`; its name is importable |
| An `extern` variable | A global the program reads and assigns in place |
| An enum constant, an integer `#define` | An `int` constant; a sign and a suffix (`(-17)`, `0xff00u`) are kept |

A declaration the interface cannot express is left out, and a module that imports it is told why
(E5133):

- a function taking or returning a `union`;
- a `static inline` function, which defines no symbol;
- a record used by value that has a bit-field, or a member whose record type has no name.

A name the headers do not declare at all is E1145.

## The manifest

```toml
headers = ["counter.h"]            # a dependency's interface, read with Clang
sources = ["counter.c"]            # compiled into every program using it
include = ["include"]              # header directories
defines = ["NDEBUG", "LEVEL=2"]    # -D, as NAME or NAME=VALUE
cflags = ["-fwrapv"]               # other Clang flags, for every source
cxxflags = ["-std=c++20"]          # Clang flags for its C++ sources alone
libs = ["m"]                       # C libraries its code calls
archives = ["lib/libfoo.a"]        # static libraries linked with its code
whole_archives = ["lib/libapi.a"]  # static libraries linked whole
also_in = ["vendor.engine"]        # C modules whose archives hold this code already (below)
inline = true                      # compiled to bitcode, inlined with the Jac (below)
export = true                      # the program exports its symbols (below)
shared = "counter"                 # built into a shared library beside the program (below)

[files."counter.c"]                # flags for one source, besides the module's:
defines = ["COUNTER_FAST"]         # include, defines and cflags

[target.linux]                     # added for one target
sources = ["counter_posix.c"]

[target.darwin]
frameworks = ["CoreFoundation"]    # macOS frameworks its code calls
```

- Every key is optional. A dependency with no `headers` (one that is only `archives`, say: a
  library built elsewhere) has no interface: a program binds its functions by declaring them
  (below). `headers` is a dependency's key alone: a module of the project's own takes its
  interface from its files.
- Paths in `headers`, `sources`, `include`, `archives`, `whole_archives`, a files table's name
  and its `include` are relative to the module's directory, and may climb out of it
  (`archives = ["../../api/libplain.a"]`). A files table's `include` must name a directory
  (E5132).
- A target table is named by an operating system (`darwin`, `linux`, `windows`), an architecture
  (`x86_64`, `aarch64`) or both (`"darwin.aarch64"`). What it holds is added to the module's lists
  when the program is built for that target; it may hold files tables too.
- `frameworks` names the macOS frameworks the module's code calls, so it belongs in
  `[target.darwin]`. At the top level it
  is refused (E5132, `macOS's go in [target.darwin]`) in a build for another operating system.
- `{lib}` in a path is the toolchain's `lib/` directory, and `{platform}` the program's platform
  (`linux-x86_64`, `macos-aarch64`, `windows-x86_64`, ...). So a module builds on the C libraries
  the toolchain ships for each platform:

  ```toml
  include = ["{lib}/clibs/{platform}/include"]
  archives = ["{lib}/clibs/{platform}/lib/libz.a"]
  ```

  A path naming any other place (`{root}`) is E5132.
- A define's value may name `{lib}`, `{platform}` and `{dir}`, the module's own directory, each as
  a C string's contents: `defines = ['DATA_DIR="{dir}/data"']`.
- An assembly source (`.S`, `.s`) is compiled too.
- `prebuilt_shared = "lib/foo"` (Windows) links `lib/foo.lib` and copies `lib/foo.dll` beside the
  program.
- An archive may have a shared library that holds the same code: a file `<archive>.shared` beside
  it names the library, by a path from the archive's directory (`libfoo.a.shared` holding
  `libfoo.so`). On Linux a plain build then links the library, not the archive, and the program
  finds it where it was at the build; a `--release` build links the archive in
  ([build](../toolchain/build.md#--release)). jac's own `lib/` says this of LLVM's archives.
- A key the manifest does not know is E5132.

### Shared, exported and whole

- **`shared = "<name>"`** builds the module's code into a shared library, `lib<name>.so`,
  `lib<name>.dylib` or `<name>.dll`, which the build writes beside the program and the program
  loads. Every module naming the same `shared` goes into the same library. A build writes the
  library again when it is missing, and programs built into one directory share it.
- **`export = true`** makes the program export the module's symbols, those of its sources and of
  the static libraries it links, as an interpreter linked with `--export-dynamic` does, for the
  shared libraries the program loads to link against. Nothing else of the program is exported:
  its Jac, the other C modules (what their assembly sources define included) and its Rust
  modules are linked hidden. That holds for an ELF or Mach-O program. A Windows program exports nothing this way: there what an interpreter exports
  is its DLL's, as CPython's C API is `python315.dll`'s.
- **`whole_archives`** links every object of an archive, not only those the link reaches. That is
  what a module that exports a C API needs of a library whose functions it exports though nothing
  in the program calls them.
- **An archive several modules name**, by one path or by several leading to the same file, is
  linked once into each output (the program, or a `shared` library), and whole if any of them
  lists it in `whole_archives`.
- **`also_in`** names, by their dotted names, the C modules that already hold this module's
  code: a library another module links whole that was built with these same sources. In a
  program with one of them the sources are not compiled, and the functions the headers declare
  are that module's; the code is in the program once either way. The runtime's expat is such a
  module: the interpreter a program using Python links has expat built in, under the same
  names.

## Inline modules

A module whose manifest says `inline = true` compiles to LLVM bitcode instead of objects, and the
program's module links it in, each source a unit of its own. The optimizer then inlines across its
C and the Jac, as it does between Jac modules, at the cost of optimizing its code again with the
program's on every build. C's own constructs carry through: `__attribute__((constructor))` functions run before
the program's code and `destructor` ones after it, and `used` data, weak references and computed
gotos are kept. `jac build --c-archive` builds no program, so there an inline module compiles to
objects, which the archive holds with every other module's.

## C++ sources

A source Clang takes for C++ by its name (`.cc`, `.cpp`, `.cxx`, ...) compiles as
[`jac c++`](c-and-cpp.md) compiles it, with libc++ and the module's `cxxflags` besides its
`cflags`. The headers are still read as C, so Jac binds what the module declares `extern "C"`:

```c
#ifdef __cplusplus
extern "C" {
#endif
int64_t words_distinct(const char *csv);
#ifdef __cplusplus
}
#endif
```

C++ static objects are constructed before the program's code runs, and exceptions thrown and
caught inside the C++ work. Every program and shared library links the toolchain's C++ runtime
(libc++, libc++abi, and libunwind except on macOS) statically, after everything else, so the linker
takes only what something references, and a program that references none of it links none.

## Wiring C modules

In a project with an `archwire.jac`, wires connect C modules as they connect Jac modules (see
[Import wiring](../language/modules-wiring.md), `jac docs graph import`).

A C module of the project's own is wired by its files:

- **A C file to Jac** (`shapes.shapes ++> main { point, point_add }`): binds those names in the
  Jac module, as `import from` does. The provider is the file that gives the name: the source that
  defines a function or a variable, whichever header declares it, and the file that holds a type,
  an enumerator or a macro. A name another file gives is E1145.
- **A C file to a C file** (`shapes.shapes --> geom.geom { shape }`): declares what `geom.c` uses of
  `shapes.h`, which Clang holds to the sources ([A C module's files](#a-c-modules-files)). The
  module that holds `geom.c` is then built with the other on its include path, and the other is
  in every program it is in.
- A wire from the module itself (`shapes ++> main { point }`, `shapes ++> geom;`) is E1576, whose
  message gives the wires to write in its place.

A dependency is wired whole, and so is a crate:

- **C to Jac** (`zlib ++> main { crc32 }`): binds those names in the Jac module.
- **C to C** (`zlib ++> png;`): `png`'s sources may include `zlib`'s headers, `zlib` is built into
  every program `png` is in, and `png`'s interface uses `zlib`'s records rather than declaring its
  own.
- **Rust to C** (`tally ++> geom;`): links the crate into every program the C module is in, where
  the C module's code calls its `extern "C"` functions by name. See
  [Rust modules](rust-modules.md).

A C module takes only another C module's interface or a Rust module, whole: a wire into it from a
Jac module, or one naming items of a Rust module, is E5136. A Jac module importing a C module of its
own top-level package must use a wire (E1144); across top-level packages, an import is governed by
the edge rules as any other.

## A C module's files

A C module of the project's own is what its table builds, and its files are modules of the project
besides: `geom/geom.c` with `geom/geom.h`, the header of its name, is `geom.geom`, and
`shapes/private/circle.h`, a header no source has the name of, is `shapes.private.circle`. Where
one file uses what another declares, a `-->` wire says so, as for a file in any other language
([Declared wires](../language/modules-wiring.md#declared-wires---)):

<!-- example: not checked: a graph import block is valid only in a file named archwire.jac, beside the modules it wires -->
```jac
graph import {
    shapes.shapes --> geom.geom { SHAPE_SQUARE, shape }
    shapes.private.circle --> shapes.shapes { SHAPES_CIRCLE_FACTOR }
}
```

`geom.c` uses the type `shape` and the enumerator `SHAPE_SQUARE` that `shapes.h` declares, and
`shapes.c` the macro `SHAPES_CIRCLE_FACTOR` of `private/circle.h`.

- Clang reads each of the module's sources as it compiles it, for every platform jac builds C
  for, since each compiles code the others do not. An import is a use Clang resolved: of a
  function, a variable, a type (a `struct`, a `union`, an `enum`, a `typedef`), an enumerator or
  a macro. An `#include` is not one: it names a header, and says nothing of which file the code
  comes from.
- A function or a variable belongs to the file that defines it, whichever header declares it. A
  type, an enumerator and a macro belong to the file that holds them.
- A C module is the project's own where `jac.toml` holds its table (`[c."geom"]`). One with a
  `cmodule.toml` that `jac.toml` does not hold is a dependency, one module whole, and so are a
  system's and a library's headers.
- These wires are checked by `jac arch` and the editor, and mended by `jac fmt --fix`.

## Declaring a C module's functions yourself

A module of another top-level package, or of a project with no archwire, may also bind a C
module's functions by declaring them, in the form that binds a [C library](c-libraries.md). The
dotted name names the C module, which the program then builds. Under an `archwire.jac` this is a
dependency's form alone: for a C module of the project's own it is E1144, since a wire from the
file that defines a function brings it, declared in a header or not.

<!-- example: not checked: needs the C module ext/plain beside the program -->
```jac
import from ext.plain {
    def plain_twice(x: i32) -> i32;
    def plain_offset(x: int) -> int;
}

with entry {
    print(plain_twice(i32(21)), plain_offset(24));
}
```

- Where the headers declare the function, the declaration must agree with theirs: the same
  parameters, each of the same type and passed the same way, the same result, and variadic only
  if theirs is (E5145, whose message gives the headers' signature). A `const char *` parameter
  may be declared as any one of `str`, `bytes` and `bytearray`.
- A function no header declares, such as one only a source defines, is the declaration's alone
  to describe.
- A record the declarations name is their own, never the headers' record of that name; bind a
  function that takes or returns a record through a wire or an import of the module instead.
- A dotted name that names a C module binds it even where a [project library](c-libraries-linking.md#a-library-the-project-provides)
  of that name exists too.

## Building

- Each source compiles with the Clang in jac to an object the link takes, as a C build compiles
  it, for the program's target.
- Clang's output is cached under a key of what alone decides it: the Clang version, the command
  line and the content of every file the compilation read. The toolchain's and the project's
  directories enter the key as what they are, not where they are. So an unchanged file compiles
  once, for every jac with the same Clang, every install of the toolchain and every copy of the
  project; a new jac with the same Clang compiles no C again.
- C modules build for every target [`jac cc`](c-and-cpp.md) builds for. `wasm32-wasi` takes none
  yet (E5090).
- `jac build --c-archive` writes a program's C modules as one static library for another build
  system to link; see [Building programs](../toolchain/build.md) (`jac docs build`).

## What goes wrong

| Code | Cause |
|---|---|
| E5132 | The manifest has a key jac does not know, a value of the wrong kind, a place other than `{lib}` and `{platform}` in a path, a files table's `include` that is no directory, or `frameworks` outside `[target.darwin]` in a build for another operating system |
| E5134 | The interface headers do not compile; Clang's errors are printed first |
| E5135 | A source does not compile; Clang's errors are printed first |
| E5133 | The name is something the interface cannot express, and the message says what |
| E1145 | The headers declare no such name |
| E5145 | A declaration that disagrees with the headers |
| E5136 | A wire into a C module from a Jac module, or naming items of a Rust module |
| E1144 | A Jac module imports its own package's C module instead of taking a wire, or declares the functions of a C module of the project's own |
| E1576 | A wire from a C module of the project's own, where its files are its modules |
| E5158 | A `headers` key in the table of a C module of the project's own |
| E5090 | A C module in a build for `wasm32-wasi` |

`jac docs E5133` prints any of these with its message.

## Differences from Python and from the reference design

- In Python, C code reaches a program as an extension module written against CPython's C API, or
  through `ctypes` or `cffi`. Here plain C is compiled into the program and called directly, with
  its types read from its headers.
- The reference design has no C modules.
