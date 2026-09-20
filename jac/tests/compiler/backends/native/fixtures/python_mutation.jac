import operator;
import types;

def mutate -> bool {
    values = operator.add([1], [2]);
    alias = values;
    values += [3];
    values[1] = 9;
    values[::2] = [7, 8];
    namespace = types.SimpleNamespace(value=1);
    namespace.value += 2;
    namespace.extra = values;
    return alias is values
        and alias[0] == 7
        and alias[1] == 9
        and alias[2] == 8
        and namespace.value == 3
        and namespace.extra is alias;
}

def invalid_assignment {
    values = operator.add([1], [2]);
    values[7] = 9;
}

def invalid_attribute {
    value = types.SimpleNamespace();
    value.__dict__ = {};
}

def augmented_order {
    types.SimpleNamespace(role="target").value += types.SimpleNamespace(
        role="rhs"
    ).value;
}

def assignment_order {
    types.SimpleNamespace(role="target").value = types.SimpleNamespace(
        role="rhs"
    ).value;
}
