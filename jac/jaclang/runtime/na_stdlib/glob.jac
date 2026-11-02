import from os.path { split, join, isdir }
import from fnmatch { fnmatchcase }

def:pub has_magic(s: str) -> bool;

def:pub escape(pathname: str) -> str;

def _ishidden(p: str) -> bool;

def _isrecursive(pattern: str) -> bool;

def _list_names(dirname: str, dironly: bool) -> list[str];

def _glob1(
    dirname: str, pattern: str, dironly: bool, include_hidden: bool
) -> list[str];

def _glob0(dirname: str, basename: str) -> list[str];

def _rlistdir(
    dirname: str, dironly: bool, include_hidden: bool, prefix: str, out: list[str]
);

def _glob2(dirname: str, dironly: bool, include_hidden: bool) -> list[str];

def _iglob(
    pathname: str, recursive: bool, dironly: bool, include_hidden: bool
) -> list[str];

def _glob_all(pathname: str, recursive: bool, include_hidden: bool) -> list[str];

def:pub `glob(
    pathname: str, recursive: bool = False, include_hidden: bool = False
) -> list[str];

def:pub iglob(
    pathname: str, recursive: bool = False, include_hidden: bool = False
) -> list[str];
