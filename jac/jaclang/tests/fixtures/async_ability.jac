import asyncio;
import from typing { Coroutine }

node MyNode {
    has val: int;

    can foo1 with MyWalker entry {
        print("foo1");
    }

    async can foo2 with MyWalker entry {
        print("foo2");
    }
}

edge MyEdge {
    has value: int;
}

async def fun {
    print("Async function");
}

async walker MyWalker {
    has name: str;

    async can do_print with MyNode entry {
        print("I am here man", here);
        visit [-->];
        await fun();
    }

    can foo3 with MyNode entry {
        print("foo3");
    }
}

with entry {
    root ++> (node1 := MyNode(5));
    node1 +>: MyEdge(100) :+> MyNode(10);
    node1 +>: MyEdge(200) :+> MyNode(15);
    walker1 = MyWalker("Mylife");
    async def foo(w: W, a: A) -> None {
        print("Let's start the task");
        x = w spawn a;
        print("It is Coroutine task", isinstance(x, Coroutine));
        await x;
        print("Coroutine task is completed");
    }
    asyncio.run(foo(walker1, node1));
}
