obj File { has fd: int = 0; }

def take(x: File) -> None {}

with entry {
    f: own File = File();
    take(f);
}
