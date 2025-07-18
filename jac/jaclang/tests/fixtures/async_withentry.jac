async def say_hello(){
    print("Hello");
    await asyncio.sleep(1);
    print("World!");
}

with entry {
    await asyncio.gather(
        say_hello(),
        say_hello()
    ); 

    await say_hello();
}