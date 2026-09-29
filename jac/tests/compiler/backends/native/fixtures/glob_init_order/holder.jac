"""Globals computed from `table.MEMBERS` while this module initializes."""

def spec_name -> str {
    return "SemLock";
}

import from table { MEMBERS }

obj TypeDef {
    has name: str,
        offsets: list[int];
}

glob SPEC = TypeDef(
         name=spec_name(), offsets=[member.offset for member in MEMBERS]
     ),
     COUNT: int = len(MEMBERS),
     NAMES: list[str] = [f"{member.name}" for member in MEMBERS];
