"""Example of multiple inheritance."""

obj Parent {
    def init {
    # Parent initialization
    }

    def speak -> None abs;  # Abstract method

}

obj Mom(Parent) {
    def init {
        # Mom initialization
        Parent.init();
    }

    def speak -> None {
        print("I'm good at swimming!");
    }
}

obj Dad(Parent) {
    def init {
        # Dad initialization
        Parent.init();
    }

    def speak -> None {
        print("I'm good at running!");
    }
}

obj Child(Mom, Dad) {  #Child inherits from Mom and Dad
    def speak -> None {
        # Child initialization
        Mom.speak();
        Dad.speak();
    }
}
