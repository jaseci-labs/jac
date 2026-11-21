"""The client pipeline installs React 19, so `ref` is an ordinary prop.

Radix positions a popper by taking a ref on the element its trigger renders.
With `asChild` that element is the child the trigger clones, so when the child
is a jac component the ref has to reach the component's host node. On React 18
a plain function component drops it (`Function components cannot be given
refs`), the popper gets no anchor, and it lands at the viewport origin -- the
jaclang.org sidebar's account dropdown rendered at a negative y, and the site
had to route around it with styled trigger primitives.

React 19 delivers `ref` as an ordinary prop, so a component that spreads its
rest props onto its host element forwards it with no `forwardRef` anywhere.
This suite pins the version; `tests/runtimelib/test_react19_ref_forwarding.jac`
mounts a compiled component under jsdom and reads the ref back off the DOM.
"""

import from jaclang.client.npm_provider { CORE_DEV_DEPS, CORE_RUNTIME_DEPS }

test "the client runtime pins React 19" {
    for name in ["react", "react-dom"] {
        pin = CORE_RUNTIME_DEPS[name];
        assert pin.startswith("^19.") , (
            f"{name} must be pinned to React 19 so `ref` arrives as a plain prop "
            f"on compiled components; got {pin}"
        );
    }
    for name in ["@types/react", "@types/react-dom"] {
        pin = CORE_DEV_DEPS[name];
        assert pin.startswith("^19.") , (
            f"{name} must track the React 19 runtime pin; got {pin}"
        );
    }
}
