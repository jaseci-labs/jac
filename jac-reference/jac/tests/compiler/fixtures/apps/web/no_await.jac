import from ..social_app { greet, Profile }

def use_it -> str {
    p: Profile = greet("x");
    return p.name;
}
