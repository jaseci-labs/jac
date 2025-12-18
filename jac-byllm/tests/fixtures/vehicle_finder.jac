import from byllm.lib { MockLLM }

glob llm: MockLLM = MockLLM(
    model_name="mockllm",
    config={
       "outputs": [[0, 2]]
    }
);

node VehicleShowroom {
    can show_vehicles with showroom_visitor entry {
        print("Welcome to the Vehicle Showroom! Here are the vehicles available:\n");
        visit [-->] by llm(
            incl_info={
                "Wheel number of the vehicle": str(visitor.vehicle_wheel_number)
            }
        );
    }
}

node Car {
    has wheel_count: int = 4;

    can act with showroom_visitor entry {
        print("Car: A sleek sedan with modern features.");
    }
}

node Bike {
    has wheel_count: int = 2;

    can act with showroom_visitor entry {
        print("Bike: A sporty mountain bike perfect for off-road adventures.");
    }
}

node Van {
    has wheel_count: int = 4;

    can act with showroom_visitor entry {
        print("Van: A spacious van ideal for family trips.");
    }
}

walker showroom_visitor {
    has vehicle_wheel_number: list[int];

    can visit_showroom with `root entry {
        print("Visitor: Entering the showroom...");
        visit [-->];
    }
}

with entry {
    show_room = root ++> VehicleShowroom();
    show_room ++> Car();
    show_room ++> Bike();
    show_room ++> Van();

    showroom_visitor([4]) spawn root;
}
