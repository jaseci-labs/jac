# Delete Statements
with entry {
    # Delete list element
    x = [1, 2, 3, 4, 5];
    print(x);
    del x[2] ;
    print(x);

    # Delete variable
    y = 100;
    print(y);
    del y ;

    # Delete dictionary item
    d = {"a": 1, "b": 2, "c": 3};
    print(d);
    del d["b"] ;
    print(d);

    # Delete slice
    numbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    print(numbers);
    del numbers[2:5] ;
    print(numbers);

    # Delete nested index
    matrix = [[1, 2], [3, 4], [5, 6]];
    print(matrix);
    del matrix[1] ;
    print(matrix);

    # Delete from list
    lst = [10, 20, 30];
    del lst[1] ;
    print(lst);

    # Delete multiple elements
    data = [0, 1, 2, 3, 4, 5];
    del data[0] ;
    del data[2] ;
    print(data);
}
