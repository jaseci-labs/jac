import time;
import asyncio;
import from typing { Coroutine }
node A {
    has val: int;
}

async walker W {
    has num: int;

    async can do1 with A entry {
        print("A Entry action ", here.val);
        visit [here-->];
    }
}

with entry {
    root ++> (a1 := A(1)) ++> [a2 := A(2), a3 := A(3), a4 := A(4)];
    w1 = W(8);
    async def foo(w: W, a: A) -> None {
        print("Let's start the task");
        x = w spawn a;
        print("It is Coroutine task", isinstance(x, Coroutine));
        await x;
        print("Coroutine task is completed");
    }
    asyncio.run(foo(w1, a1));
}
