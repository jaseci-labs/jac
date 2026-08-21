"""`forward` seeds on its Module base; `step` joins the region only through the
`self.step(...)` edge, and `unused` must stay untouched despite its print."""
import torch;

class Net(torch.nn.Module) {
    def forward(self: any, x: any) -> any {
        y = torch.relu(x);
        return self.step(y);
    }

    def step(self: any, x: any) -> any {
        print("STEP-EFFECT", x);
        return x * 2.0;
    }

    def unused(self: any, x: any) -> any {
        print("UNUSED-EFFECT", x);
        return x;
    }
}
