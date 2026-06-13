"""Typed edge endpoints narrow neighbour traversals to the declared node type (#6657)."""
node Profile { has name: str = ""; }
node Tweet { has txt: str = ""; }
edge Follow: Profile --> Profile {}
edge Post: Profile --> Tweet {}
edge Plain {}
edge TimedFollow(Follow) { has at: str = ""; }

with entry {
    a = Profile();
    t = Tweet();
    follow_out = [a ->:Follow:->];      # target Profile
    post_out = [a ->:Post:->];          # target Tweet
    post_in = [t <-:Post:<-];           # source Profile
    untyped = [a ->:Plain:->];          # any -- gradual typing preserved
    inherited = [a ->:TimedFollow:->];  # inherits Follow's endpoints -> Profile
    one = [a ->:Post:->][0];            # Tweet element off the narrowed list
    field_read = one.txt;               # str -- field read off a narrowed element
}
