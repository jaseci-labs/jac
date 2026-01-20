# Features Test Page - Backend Logic
# This file is intentionally kept empty to demonstrate the separation of concerns
# where UI logic resides in .cl.jac files and backend walker logic in app.jac

# All walker implementations for this feature are in main.jac
# This demonstrates that you can have separate .jac files for different purposes
# Features Test - Backend Walkers
# This file demonstrates walker functionality for testing various JAC features

import from datetime { datetime, timedelta }

# Node definition for storing test data
node TestData {
    has message: str;
    has count: int = 0;
    has created_at: str = "";
}

# Walker: Create test data
walker create_test_data {
    has message: str;

    can create with `root entry {
        new_data = here ++> TestData(
            message=self.message,
            count=1,
            created_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        );
        report new_data;
    }
}

# Walker: Read all test data
walker read_test_data {
    can read with `root entry {
        visit [-->(`?TestData)];
    }

    can report_data with exit {
        report here;
    }
}

# Walker: Update test data
walker update_test_data {
    has new_message: str;

    can update with TestData entry {
        here.message = self.new_message;
        here.count = here.count + 1;
        report here;
    }
}

# Walker: Delete test data
walker delete_test_data {
    can delete with TestData entry {
        del here;
        report {"status": "deleted"};
    }
}

# Walker: String manipulation test
walker test_string_methods {
    has input_text: str;

    can process with `root entry {
        result = {
            "original": self.input_text,
            "uppercase": self.input_text.upper(),
            "lowercase": self.input_text.lower(),
            "capitalized": self.input_text.capitalize(),
            "reversed": self.input_text[::-1],
            "length": len(self.input_text),
            "words": self.input_text.split(),
            "trimmed": self.input_text.strip(),
            "replaced": self.input_text.replace("test", "demo")
        };
        report result;
    }
}

# Walker: Array/List operations test
walker test_list_operations {
    has numbers: list;

    can process with `root entry {
        result = {
            "original": self.numbers,
            "sorted": sorted(self.numbers),
            "reversed": list(reversed(self.numbers)),
            "sum": sum(self.numbers),
            "max": max(self.numbers) if len(self.numbers) > 0 else 0,
            "min": min(self.numbers) if len(self.numbers) > 0 else 0,
            "length": len(self.numbers),
            "doubled": [x * 2 for x in self.numbers]
        };
        report result;
    }
}

# Walker: Complex data processing
walker process_complex_data {
    has items: list;

    can process with `root entry {
        processed = [];
        for item in self.items {
            processed.append({
                "id": item.get("id", 0),
                "name": item.get("name", "").upper(),
                "value": item.get("value", 0) * 2,
                "processed_at": datetime.now().strftime("%H:%M:%S")
            });
        }

        result = {
            "original_count": len(self.items),
            "processed_count": len(processed),
            "items": processed,
            "total_value": sum([p["value"] for p in processed])
        };

        report result;
    }
}

# Re-export client components from the standalone client module
cl {
    import from .budget_planner_ui { BudgetPlanner as BudgetPlannerUI }

    def:pub BudgetPlanner -> any { return <BudgetPlannerUI />; }
}
