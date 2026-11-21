import module_a;

with entry {
    print(f"Absolute import - VALUE_A: {module_a.VALUE_A}");
    print(f"Absolute import - greet(): {module_a.greet()}");
}
