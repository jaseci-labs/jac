import json;

glob raw: any = json.loads("{\"x\": \"three\"}"),
     counts: dict[str, int] = raw;

with entry {
    print("reached", len(counts));
}
