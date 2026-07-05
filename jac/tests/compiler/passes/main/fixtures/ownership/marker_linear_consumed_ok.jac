obj File { has fd: int = 0; }

def close(x: File) -> None {}

with entry {
    f: linear File = File();
    close(f);
}
