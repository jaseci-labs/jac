import from jaclang { JacRuntime }

glob dynamic_module_source = """
import from arch_create_util {UtilityNode}

walker DynamicWalker {
can start with entry {
print("DynamicWalker Started");
here ++> UtilityNode(data=42);
visit [-->](`?UtilityNode);
}

def UtilityNode {
here.display_data();
}
}
""";

with entry {
    node_arch = JacRuntime.create_archetype_from_source(
        dynamic_module_source, module_name="dynamic_module"
    );
    walker_obj = JacRuntime.spawn_walker(
        'DynamicWalker', module_name="dynamic_module",
    );
    root spawn walker_obj;
}
