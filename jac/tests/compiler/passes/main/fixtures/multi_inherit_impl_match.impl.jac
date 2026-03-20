"""Implementation for multi_inherit_impl_match.jac"""

impl MultiInheritanceClass.my_static_method(x: int) -> int {
    return x * 2;
}

impl MultiInheritanceClass.my_instance_method -> int {
    return self.value_a + self.value_b;
}
