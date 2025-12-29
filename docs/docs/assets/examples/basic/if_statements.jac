glob x = 15;

with entry {
    if 0 <= x <= 5 {
        print("Not Bad");
    } elif 6 <= x <= 10 {
        print("Average");
    } else {
        print("Good Enough");
    }
}
