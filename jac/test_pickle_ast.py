"""Test script to reproduce pickle recursion issue with AST nodes.

Usage:
    python test_pickle_ast.py [file_path]

If no file path provided, uses a default test file.
"""

import sys
import pickle
import argparse

def main():
    parser = argparse.ArgumentParser(description="Test pickle recursion with AST")
    parser.add_argument("file_path", nargs="?",
                        default="/home/kuggix/jaseci/jac/jaclang/langserve/impl/engine.impl.jac",
                        help="Path to .jac file to compile and pickle")
    parser.add_argument("--limit", type=int, default=1000,
                        help="Test with this recursion limit (default: 1000)")
    args = parser.parse_args()

    # Show current recursion limit
    print(f"Default recursion limit: {sys.getrecursionlimit()}")
    print(f"Testing with limit: {args.limit}")

    # Import the compiler
    from jaclang.pycore.program import JacProgram

    file_path = args.file_path
    print(f"\nCompiling: {file_path}")

    with open(file_path, "r") as f:
        source = f.read()

    print(f"Source length: {len(source)} chars")

    # Compile the file
    program = JacProgram()
    module = program.compile(
        file_path=file_path,
        use_str=source,
        type_check=True,
        no_cgen=True,
    )

    # Manually add to hub (like the worker does)
    if module and module.loc:
        program.mod.hub[file_path] = module

    print(f"\nCompilation complete!")
    print(f"Hub keys ({len(program.mod.hub)}): {list(program.mod.hub.keys())[:5]}...")
    print(f"Errors: {len(program.errors_had)}")
    for err in program.errors_had[:3]:
        print(f"  - {err}")

    # Now try to pickle with specified recursion limit
    print("\n" + "=" * 60)
    print(f"Attempting to pickle hub with recursion limit = {args.limit}...")
    print("=" * 60)

    old_limit = sys.getrecursionlimit()
    try:
        sys.setrecursionlimit(args.limit)
        data = {"hub": program.mod.hub}
        pickled = pickle.dumps(data)
        print(f"SUCCESS: Pickled {len(pickled):,} bytes ({len(pickled)/1024/1024:.2f} MB)")

        # Also test unpickling
        unpickled = pickle.loads(pickled)
        print(f"SUCCESS: Unpickled, hub keys: {list(unpickled['hub'].keys())[:3]}...")
    except RecursionError as e:
        print(f"RECURSION ERROR: {e}")
        print("\nThis is the error that happens in the LSP worker!")
        print("The fix is to temporarily increase recursion limit during pickle.")
    finally:
        sys.setrecursionlimit(old_limit)

    print(f"\nRestored recursion limit to: {sys.getrecursionlimit()}")


if __name__ == "__main__":
    main()
