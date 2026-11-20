"""Native A2 (issue #6930): __class__.__name__ / type(self).__name__ lowering.

`kind` is defined only on the base `Widget`, yet a subclass instance must report
its own *runtime* class name -- so the access is routed through the instance's
vtable, not frozen to the declaring class. A standalone class with no hierarchy
(`Lone`) has no vtable and lowers to a constant name load.
"""

obj Widget {
    def kind -> str {
        return self.__class__.__name__;
    }

    def kind_via_type -> str {
        return type(self).__name__;
    }
}

obj Button(Widget) {}

obj Slider(Widget) {}

# No parents and no subclasses -> no vtable -> constant-load fast path.
obj Lone {
    def kind -> str {
        return self.__class__.__name__;
    }
}

# Method-less hierarchy: `Tag` is vtable-flagged (it has subclasses) but no class
# in its MRO declares a method. The vtable must still be emitted so field 0 is
# written at construction and the name read off a base-typed receiver stays
# polymorphic instead of dereferencing an uninitialized slot (PR #6933 review).
obj Tag {}

obj SubA(Tag) {}

obj SubB(Tag) {}

def tag_name(t: Tag) -> str {
    return t.__class__.__name__;
}

def suba_name -> str {
    return tag_name(SubA());
}

def subb_name -> str {
    return tag_name(SubB());
}

def button_kind -> str {
    return Button().kind();
}

def slider_kind -> str {
    return Slider().kind();
}

def widget_kind -> str {
    return Widget().kind();
}

def button_kind_via_type -> str {
    return Button().kind_via_type();
}

def lone_kind -> str {
    return Lone().kind();
}

with entry {
    print(Button().kind());
    print(Slider().kind());
    print(Widget().kind());
    print(Lone().kind());
}
