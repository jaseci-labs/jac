include import_star;
import from datetime { datetime }

with entry {
    x: str = Foo().foo();
    y: int = Bar().bar();

    d: str = datetime.date();
}
