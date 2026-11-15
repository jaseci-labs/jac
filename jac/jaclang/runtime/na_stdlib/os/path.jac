import os;


glob sep: str = "/",
     extsep: str = ".",
     pardir: str = "..",
     curdir: str = ".";

def:pub exists(path: str) -> bool;

def:pub isfile(path: str) -> bool;

def:pub isdir(s: str) -> bool;

def:pub realpath(filename: str) -> str;

def:pub getsize(filename: str) -> int;

def:pub getmtime(filename: str) -> float;


def:pub isabs(s: str) -> bool;


def _all_slashes(s: str) -> bool;


def _rstrip_slashes(s: str) -> str;


def:pub split(p: str) -> tuple[(str, str)];


def:pub dirname(p: str) -> str;


def:pub basename(p: str) -> str;


def:pub splitext(p: str) -> tuple[(str, str)];


def _join2(a: str, b: str) -> str;


def:pub join(
    a: str,
    p1: (str | None) = None,
    p2: (str | None) = None,
    p3: (str | None) = None,
    p4: (str | None) = None
) -> str;


def:pub abspath(path: str) -> str;


def:pub normcase(s: str) -> str;


def:pub relpath(path: str, start: str = ".") -> str;


def:pub normpath(path: str) -> str;


def:pub expanduser(path: str) -> str;
