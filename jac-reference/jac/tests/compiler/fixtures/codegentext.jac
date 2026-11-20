"""Various samples to see code generated correctly"""

import inspect;

def say(x: any) -> any {
    return x;
}

def dump(x: any) -> any {
    return x;
}

def chained(x: any) -> any {
    return x;
}

with entry {
    a = (5 + 10) * 2;
    {"name": "value"} |> (len |> print |> dump) |> say;
}

with entry {
    a = (5 + 10) * 2;
    {"name": "value"} |> (len |> print :> dump) |> say;
}

with entry {
    chained <| print <| print <| print <| {"name": "value"};
}

obj Registry {
    has sig: any = None,
        registry: dict[str, str] = {};

    def func(*args: any, **kwargs: any) -> None {
        return;
    }

    def wire(*args: any, **kwargs: any) {
        (*args, **kwargs) |> self.func;
        self.sig = self.func |> inspect.signature;
        |> self.registry.items;
    }
}

with entry {
    with open("file.txt") as f, open("file2.txt") as f2 { }
}

enum Color { RED = 1, GREEN, BLUE = 3 }
