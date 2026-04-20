"""Fixture: SV returns graph fragments (nodes + edges) to CL.

Tests the most complex case: walker reports containing node objects
with edge connectivity, where the client needs to preserve
graph structure (not just flat fields).
"""

node Department {
    has name: str,
        budget: float = 0.0;
}

node Employee {
    has name: str,
        role: str,
        salary: float = 0.0;
}

edge BelongsTo {}

edge Manages {
    has since: str = "";
}

walker get_org_tree {
    can enter_root with Root entry {
        visit [-->[?:Department]];
    }

    can enter_dept with Department entry {
        report {
            "department": here,
            "employees": [-->[?:Employee]]
        };
    }
}

walker add_employee {
    has name: str,
        role: str,
        dept_id: str;

    can add with Department entry {
        emp = here ++> Employee(name=self.name, role=self.role);
        report emp;
    }
}

walker transfer_employee {
    has emp_id: str,
        new_dept_id: str;

    can transfer with Root entry {
        report {"transferred": True, "emp_id": self.emp_id};
    }
}

cl {
    def:pub app -> JsxElement {
        has departments: list = [],
            selectedDept: Any = None;

        async can with entry {
            result = root spawn get_org_tree();
            departments = result.reports;
        }

        async def addEmployee(name: str, role: str) -> None {
            if selectedDept {
                result = jid(selectedDept) spawn add_employee(
                    name=name, role=role, dept_id=jid(selectedDept)
                );
                newEmp = result.reports[0][0];
            }
        }

        return <div>
            {[<div key={d.department.name}>
                <h2>{d.department.name}</h2>
                {[<span key={e.name}>{e.name} ({e.role})</span>
                  for e in d.employees]}
            </div> for d in departments]}
        </div>;
    }
}
