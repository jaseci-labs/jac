node Spot {
    def helper {
        report "helper";
    }

    can greet with Visitor entry {
        def inner {
            report "inner";
        }
        report "hi";
        self.helper();
        inner();
    }
}

walker Visitor {
    obj Tally {
        def bump {
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

impl Later{
    can go with Root entry;
}

impl Later.go{
    report "impl";
}

with entry {
    print(sorted((root spawn Visitor()).reports));
    print((root spawn Later()).reports);
}
