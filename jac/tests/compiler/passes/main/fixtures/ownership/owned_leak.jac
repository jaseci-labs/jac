obj File { has fd: int = 0; }

with entry {
    f: own File = File();
    print("done");
}
