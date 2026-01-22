obj Company {
    has revenue: int = 5;

    obj Department;

    def postinit;}

impl Company.postinit{
    self.employee_count = self.revenue * 3;
}

impl Company.Department{
    obj Team;
    def setup;
}

impl Company.Department.setup {
    self.budget = 10;
}

impl Company.Department.Team {
    obj Employee;
    def configure;
}

impl Company.Department.Team.configure {
    self.project_count = 20;
}

impl Company.Department.Team.Employee {
    def onboard;
}

impl Company.Department.Team.Employee.onboard {
    self.salary = 30;
}

# with entry {
#     company = Company();
#     print(company.revenue, company.employee_count);

#     dept = company.Department();
#     dept.setup();
#     print(dept.budget);

#     team = dept.Team();
#     team.configure();
#     print(team.project_count);

#     employee = team.Employee();
#     employee.onboard();
#     print(employee.salary);
# }