import from jaclang { JacRuntime }

glob dynamic_module_source = """
import from arch_create_util {UtilityNode}

walker DynamicWalker {
can start with entry {
print("DynamicWalker Started");
here ++> UtilityNode(data=42);
visit [-->][?:UtilityNode];
}

can handle with UtilityNode entry {
}
}
""";

import os;
with entry {
    node_arch = JacRuntime.create_archetype_from_source(
        dynamic_module_source,
        module_name="dynamic_module",
        base_path=os.path.dirname(os.path.abspath(__file__))
    );
    walker_obj = JacRuntime.spawn_walker(
        'DynamicWalker', module_name="dynamic_module",
    );
    root spawn walker_obj;
}
