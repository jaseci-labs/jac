import json;

glob raw: any = json.loads("{\"x\": 3}"),
     counts: dict[str, int] = raw;

with entry {
    print("reached", len(counts));
}
