# Test entry point for super().__init__() through Jac compilation pipeline
from super_init_base import Child, GrandChild

if __name__ == "__main__":
    c = Child()
    gc = GrandChild()
