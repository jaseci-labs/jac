# Delete Statements

# Delete list element
glob x = [1, 2, 3, 4, 5];

with entry {
    print(x);
    del x[2] ;
    print(x);
}

# Delete variable
glob y = 100;

with entry {
    print(y);
    del y ;
}

# Delete dictionary item
glob d = {"a": 1, "b": 2, "c": 3};

with entry {
    print(d);
    del d["b"] ;
    print(d);
}

# Delete slice
glob numbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

with entry {
    print(numbers);
    del numbers[2:5] ;
    print(numbers);
}

# Delete nested index
glob matrix = [[1, 2], [3, 4], [5, 6]];

with entry {
    print(matrix);
    del matrix[1] ;
    print(matrix);
}

# Delete from list
glob lst = [10, 20, 30];

with entry {
    del lst[1] ;
    print(lst);
}

# Delete multiple elements
glob data = [0, 1, 2, 3, 4, 5];

with entry {
    del data[0] ;
    del data[2] ;
    print(data);
}
