import io;
import os;

def show(f: io.FileIO, size: int) {
    chunk: bytes = f.read(size);
    print(len(chunk), chunk.decode("ascii"));
}

with entry {
    path = "fileio_probe.bin";
    with open(path, "wb") as out {
        out.write(b"0123456789abcdefghij");
    }
    with io.FileIO(path, "r") as f {
        print(f.readable(), f.seekable(), f.writable());
        show(f, 4);
        print(f.tell());
        print(f.seek(10));
        show(f, 5);
        print(f.seek(-3, 2));
        show(f, 100);
        show(f, 4);
        print(f.seek(2, 0));
        print(f.seek(3, 1));
        show(f, -1);
        show(f, 0);
        print(f.mode, f.name, f.closed);
    }
    reader = io.FileIO(path);
    data = reader.readall();
    reader.close();
    print(len(data), reader.closed);
    closed_error = False;
    try {
        reader.read(1);
    } except ValueError {
        closed_error = True;
    }
    print(closed_error);
    missing = False;
    try {
        io.FileIO("fileio_probe_missing.bin", "r");
    } except FileNotFoundError {
        missing = True;
    }
    print(missing);
    os.remove(path);
}
