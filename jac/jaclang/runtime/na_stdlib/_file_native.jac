import from c { def fopen(path: str, mode: str) -> int;  }
import from c { def fread(buffer: bytes, size: u64, count: u64, stream: int) -> u64;  }
import from c { def ferror(stream: int) -> i32;  }
import from c { def fclose(stream: int) -> i32;  }
import from c { def fseek(stream: int, off: i64, whence: i32) -> i32;  }
import from c { def ftell(stream: int) -> i64;  }

glob _SEEK_SET: int = 0,
     _SEEK_END: int = 2,
     _PREALLOC_CAP: int = 67108864;

def:pub open_stream(path: str, mode: str) -> int;

def:pub close_stream(stream: int);

def:pub read_stream(stream: int, size: int, path: str) -> bytes;

def:pub read_stream_all(stream: int, path: str) -> bytes;

def:pub seek_stream(stream: int, offset: int, whence: int, path: str) -> int;

def:pub read_file_bytes(path: str) -> bytes;
