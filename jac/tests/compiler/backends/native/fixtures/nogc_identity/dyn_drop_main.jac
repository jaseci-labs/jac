"""Own references typed as a base drop the subclass instance they hold.

`Buffer` adds its own `drop` hook and owned fields to the imported
`Resource`. Every drop of an own `Resource` reference -- replacing a
field, the end of a local's scope, a list dropping its elements, and the
container drop chain -- must run `Buffer`'s hook and drop its payload,
exactly as the reference-counted profiles and the Python backend do.
"""

import from dyn_drop_base { Payload, Resource, Holder, release_all }

obj Buffer(Resource) {
    has data: own list[int] = [],
        extra: own Payload = Payload();

    def drop {
        print("drop buffer " + self.name + " " + str(len(self.data)));
    }
    def size -> int {
        return len(self.data);
    }
}

def field_replace {
    h: own Holder = Holder();
    b: own Buffer = Buffer(name="b1", data=[1, 2, 3], extra=Payload(tag="p1"));
    h.slot = b;
    print("slot size " + str(h.slot.size()));
    c: own Resource = Resource(name="plain");
    h.slot = c;
    print("replaced");
}

def scope_end {
    r: own Resource = Buffer(name="b2", data=[4], extra=Payload(tag="p2"));
    print("scope size " + str(r.size()));
}

def list_drop {
    items: own list[Resource] = [
        Buffer(name="b3", data=[5, 6], extra=Payload(tag="p3"))
    ];
    print("list total " + str(release_all(items)));
}

with entry {
    field_replace();
    print("--");
    scope_end();
    print("--");
    list_drop();
    print("done");
}
