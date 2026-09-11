node Graph {}
node Value(Graph) {
    has value: int = 0;
}

node Token(Graph) {}
edge Child: Graph --> Graph {}
