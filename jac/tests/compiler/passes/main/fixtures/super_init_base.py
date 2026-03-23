# Test fixture for super().__init__() through Jac compilation pipeline
# Tests that Python inheritance with super() works correctly
# when routed through Jac's IR and back to Python AST


class Base:
    def __init__(self):
        print("Base init")


class Child(Base):
    def __init__(self):
        super().__init__()
        print("Child init")


class GrandChild(Child):
    def __init__(self):
        super().__init__()
        print("GrandChild init")


Child()
GrandChild()
