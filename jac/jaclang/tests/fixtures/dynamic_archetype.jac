import from jaclang.runtimelib.machine { JacMachine }
import from bar { Item }


node test_node {
    has value: int;
}


walker test_walker {
    can visit_nodes with `root entry {
        visit [-->];
    }

    can print_value with test_node | Item entry {
        print("Value:", f'{here.value}');
    }
}


walker child_walker ( test_walker ) {}


with entry {
    for value in range(1, 4) { root ++> test_node(value=value); root ++> Item(value=value); }
    node_obj = JacMachine.spawn_node(
        node_name='test_node', attributes={'value' : 0 }, module_name='__main__'
    );
    walker_obj = JacMachine.spawn_walker(
        walker_name='child_walker', module_name='__main__'
    );
    external_node = JacMachine.spawn_node(
        node_name='Item', attributes={'value' : 0 }, module_name='bar'
    );
    root ++> external_node;
    root ++> node_obj;
    print("Spawned Node:", node_obj);
    print("Spawned Walker:", walker_obj);
    print("Spawned External node:", external_node);
    root spawn walker_obj;
}
