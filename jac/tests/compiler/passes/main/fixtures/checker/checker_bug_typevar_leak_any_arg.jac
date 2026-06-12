"""An unsolved TypeVar must not leak out of a generic call.

`list(x)` where x is Any cannot relate Any to Iterable[_T]; the
degenerate solution _T := _T used to leak `list[_T]` into the result,
poisoning attribute access (`Cannot access attribute "lower" for type
"_T"`) and downstream overload checks. Unsolved → bare list (elements
any), per the PEP-484 bare-generic default.
"""
import from typing { Any }

obj ManifestHolder {
    has _client_manifest: dict[(str, Any)] = {};

    def resolve_root_app() -> str {
        names: list[str] = list(self._client_manifest.get('exports', []));
        if not names {
            return "";
        }
        by_lower: dict[(str, str)] = {};
        for n in names {
            by_lower.setdefault(n.lower(), n);
        }
        return "";
    }
}

with entry {
    m: dict[(str, Any)] = {};
    unannotated = list(m.get('exports', []));
    for n in unannotated {
        print(n.lower());
    }
    healthy = list([1, 2]);
    bad: str = healthy;   # Error: list[int] not assignable to str (solver intact)
    print(bad);
}
