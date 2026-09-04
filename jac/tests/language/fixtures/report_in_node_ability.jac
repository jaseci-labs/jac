node Spot {
    def helper -> None {
        report "helper";
    }

    can greet with Visitor entry {
        def inner -> None {
            report "inner";
        }
        report "hi";
        self.helper();
        inner();
    }
}

walker Visitor {
    obj Tally {
        def bump -> None {
            report "nested";
        }
    }

    can go with Root entry {
        here ++> Spot();
        self.Tally().bump();
        visit [-->];
    }
}

walker Later;

impl Later {
    can go with Root entry;
}

impl Later.go {
    report "impl";
}

with entry {
    print(sorted((root spawn Visitor()).reports));
    print((root spawn Later()).reports);
}
