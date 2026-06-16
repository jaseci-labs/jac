"""A factory call torch.compile(make_model()) must NOT tag the factory body:
make_model runs before torch.compile, and its RETURN value (not its body) is
what gets compiled. So the logger call inside make_model stays untagged."""
import torch;
import from logging { getLogger }

glob log = getLogger("m");

obj Model {
    def forward(x: any) -> any {
        return torch.relu(x);
    }
}

def make_model -> Model {
    log.info("building");
    return Model();
}

with entry {
    torch.compile(make_model());
}
