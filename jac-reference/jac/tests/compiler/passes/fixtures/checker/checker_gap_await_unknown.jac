"""Gap #36: AwaitExpr returns UnknownType instead of the awaited type.

No case for AwaitExpr in _get_type_of_expression_core. The await
expression should unwrap the coroutine's return type. Currently
falls through to UnknownType, so any assignment is accepted.

Expected errors:
  1. await fetch_number() assigned to str  (int -> str)
  2. await fetch_data() assigned to int    (dict -> int)
  3. await get_async_int() assigned to str (int -> str)
  4. await get_async_int() assigned to bool (int -> bool)
"""

async def fetch_number -> int {
    return 42;
}

async def fetch_data -> dict[str, int] {
    return {"a": 1};
}

async def fetch_name -> str {
    return "hello";
}

async def get_async_int -> int {
    return 99;
}

async def main_async {
    # Case 1: Basic await type mismatch
    ok1: int = await fetch_number();    # Ok: int -> int
    bad1: str = await fetch_number();   # Error: int -> str

    # Case 2: Dict return type mismatch
    ok2: dict[str, int] = await fetch_data();   # Ok
    bad2: int = await fetch_data();              # Error: dict -> int

    # Case 3: Using awaited value OK then mismatch
    name: str = await fetch_name();              # Ok
    bad3: int = await fetch_name();              # Error: str -> int

    # Case 4: Await result assigned to wrong type
    bad4: str = await get_async_int();           # Error: int -> str

    # Case 5: Another type mismatch
    val: int = await get_async_int();            # Ok
    bad5: bool = await get_async_int();          # Error: int -> bool
}
