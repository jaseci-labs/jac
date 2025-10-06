# Match Statements

with entry {
    # Basic match with literal patterns
    x = 8;
    match x {
        case 7:
            print("seven");
        case 8:
            print("eight");
        case _:
            print("other");
    }

    # Match with guard clause (if condition)
    value = 15;
    match value {
        case x if x < 10:
            print("less than 10");
        case x if x < 20:
            print("10 to 19");
        case _:
            print("20 or more");
    }

    # Match with multiple statements after case
    result = "success";
    match result {
        case "success":
            print("operation succeeded");
            status = 200;
            print(f"status: {status}");
        case "error":
            print("operation failed");
            status = 500;
        case _:
            print("unknown");
            status = 0;
    }

    # Match with different pattern types
    data = [1, 2, 3];
    match data {
        case [x]:
            print(f"single: {x}");
        case [x, y]:
            print(f"two: {x}, {y}");
        case [x, y, z]:
            print(f"three: {x}, {y}, {z}");
        case _:
            print("other length");
    }

    # Match with string patterns
    cmd = "start";
    match cmd {
        case "start":
            print("starting");
        case "stop":
            print("stopping");
        case "pause":
            print("pausing");
        case _:
            print("unknown command");
    }

    # Match with integer patterns
    code = 200;
    match code {
        case 200:
            print("OK");
        case 404:
            print("Not Found");
        case 500:
            print("Server Error");
        case _:
            print(f"code {code}");
    }
}
