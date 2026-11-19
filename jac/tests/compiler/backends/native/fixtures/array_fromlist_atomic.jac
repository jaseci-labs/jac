import from array { array }

with entry {
    values = array("i", [10]);
    try {
        values.fromlist([20, "bad"]);
        print("conversion=accepted");
    } except TypeError {
        print("conversion=rejected");
    }
    print("values=" + str(values.tolist()));
}
