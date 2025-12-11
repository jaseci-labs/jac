import os;

with entry {
    print("Hello World");
    print(os.getcwd());
}
# import tensorflow as tf;
# with entry{
#     print(tf.__version__);
# }
import random;

def entry() {
    print("Hello World");
    random.seed(42);
    print(random.randint(0, 100));

    # Generate random numbers
    print(random.random());
    print(random.uniform(1, 10));
    print(random.randint(1, 6));
    print(random.randrange(1, 10, 2));

    # Sequence operations
    random.seed(42);
    colors = ['red', 'green', 'blue', 'yellow', 'orange'];
    print(random.choice(colors));  # Random color from the list
    print(random.sample(colors, 3));  # Random sample of 3 colors from the list
    random.shuffle(colors);
    print(colors);  # Colors shuffled in-place

    # Distributions
    print(random.normalvariate(0, 1));  # Random sample from a normal distribution with mean 0 and stddev 1
    print(random.lognormvariate(0, 1));  # Random sample from a log-normal distribution with mean 0 and stddev 1

    # Seed and state
    print(random.random());
    state = random.getstate();
    random.setstate(state);
    print(random.random());
    print('\n\nyou clicked me\n\n');
}

with entry {
    entry();
}
# tkinter
import tkinter as tk;

with entry {
    __root__ = tk.Tk();
    __root__.title("Random Module Example");
    __root__.geometry("300x300");
    __label__ = tk.Label(__root__, text="Click the button to generate a random number");
    __label__.pack(pady=10);
    print(tk.Button);
}
