
with entry{

    obj A{
        has i: int = 0;

    }
    a = A();

    # For-to-by loop
    for a.i=0 to a.i<5 by a.i+=1 {
        if a.i == 3 {
            print("Skipping 3");
            continue;
        }
        print(a.i);
    }

}