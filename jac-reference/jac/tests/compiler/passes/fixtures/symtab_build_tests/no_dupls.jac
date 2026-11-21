glob a: int = 90;

obj Man {
    has name: str = '';

    def speak {
        obj Korean {
            with entry {
                print('HELLO');
                print(a);
            }

            has name: str = 'Korean';

            def speak {
                import from one { a }
                print(a);
                print('speaking Korean');
            }
        }
        k = Korean();
        k.name = 'Korean';
        print('hello world');
        print(a);
        k.speak();
    }
}

with entry {
    p = Man();
    print(p.name);
    p.speak();
}
