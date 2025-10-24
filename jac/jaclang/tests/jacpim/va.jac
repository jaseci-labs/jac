import from jaclang.runtimelib.machine {JacMachine}
node Data {
    has data: int = 0;
    def get_byte_stream() {
        return struct.pack("<Q", self.data);
    }
    def get_type_def() {
        return "uint64_t data;";
    }
}

node Result {
    has data: int = 0;
    def get_byte_stream() {
        return struct.pack("<Q", self.data);
    }
    def get_type_def() {
        return "uint64_t data;";
    }
}

walker va {
    has data: int = 0;
    def get_byte_stream() {
        return struct.pack("<Q", self.data);
    }
    def get_type_def() {
        return "uint64_t data;";
    }
    can run with Data entry {
        self.data += here.data;
        visit [-->];
    }
    def get_impl_run_on_Data() {
        return """
        walker->data += node->data;
        push_new_element_to_container(0);
        """;
    }
    can save with Result entry {
        here.data = self.data;
        print(here.data);
    }
    def get_impl_run_on_Result() {
        return """
        node->data = walker->data;
        """;
    }
}


with entry {
    N = 1500;
    vectorA = list(range(N));
    vectorB = list(range(N, 2*N));
    vectorAData = [Data(data = num) for (idx, num) in enumerate(vectorA)];
    vectorBData = [Data(data = num) for (idx, num) in enumerate(vectorB)];
    vectorCData = [Result() for (idx, num) in enumerate(vectorB)];
    for i in range(len(vectorAData)) {
        root ++> vectorAData[i];
        vectorAData[i] ++> vectorBData[i];
        vectorBData[i] ++> vectorCData[i];
    }
    JacMachine.jacpim_init();
    for i in range(len(vectorCData)) {
        wlk = va();
        JacMachine.jacpim_spawn(wlk, vectorAData[i]);
    }
    JacMachine.jacpim_start();
}