import os;
import from c { def access(path: str, mode: i32) -> i32;  }
import from c { def unlink(path: str) -> i32;  }
import from c { def rmdir(path: str) -> i32;  }
import from c { def rename(oldp: str, newp: str) -> i32;  }


def:pub which(cmd: str) -> (str | None);

def:pub copyfile(src: str, dst: str) -> str;

def:pub copy(src: str, dst: str) -> str;

def:pub copy2(src: str, dst: str) -> str;

def:pub move(src: str, dst: str) -> str;

def:pub rmtree(path: str, ignore_errors: bool = False);

def _rmtree_children(path: str, ignore_errors: bool) -> bool;

def _rmtree_walk(path: str, ignore_errors: bool) -> bool;
