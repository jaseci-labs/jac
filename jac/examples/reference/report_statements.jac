# Report Statements
walker Reporter {
    can process with `root entry {
        # Report literal value
        report 42 ;

        # Report string
        report "hello" ;

        # Report expression
        report 10 + 20 ;

        # Report variable
        x = 100;
        report x ;

        # Report list
        report [1, 2, 3] ;

        # Report dictionary
        report {"key": "value", "number": 123} ;

        # Report complex expression
        report {"result": 5 * 10, "status": "ok"} ;

        disengage;
    }
}

glob w = Reporter();

with entry {
    root spawn w;
}
