// Classes TypeScript fixture

class BasicClass {
    name: string;

    constructor(name: string) {
        this.name = name;
    }

    greet(): string {
        return "Hello, " + this.name;
    }
}

class WithModifiers {
    public myPublic: string;
    private myPrivate: number;
    protected myProtected: boolean;
    readonly myReadonly: string;
    static myStatic: number = 42;

    constructor() {
        this.myPublic = "value1";
        this.myPrivate = 1;
        this.myProtected = true;
        this.myReadonly = "readonly";
    }

    public doPublic(): void {}
    private doPrivate(): void {}
    protected doProtected(): void {}
    static doStatic(): number {
        return WithModifiers.myStatic;
    }
}

abstract class AbstractClass {
    abstract doAbstract(): void;

    doConcrete(): string {
        return "concrete";
    }
}

class Extended extends BasicClass {
    age: number;

    constructor(name: string, age: number) {
        super(name);
        this.age = age;
    }

    override greet(): string {
        return super.greet() + ", age " + this.age;
    }
}

// Async methods
class AsyncMethods {
    async fetchData(): Promise<string> {
        return "data";
    }

    *generator() {
        yield 1;
    }
}

// Getters and setters
class WithAccessors {
    private _value: number = 0;

    get value(): number {
        return this._value;
    }

    set value(v: number) {
        this._value = v;
    }
}
