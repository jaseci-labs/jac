"""A call-site wrapped model class: the region is forward, not every method.

`torch.compile(WrapNet())` compiles only `forward`; sibling methods run
eagerly through the original module. So the region seeds `forward` and closes
over its call edges: the print in `cls_helper` is deferred, while `side_step`,
which forward never calls, stays byte-identical."""
import torch;

def cls_helper(x: any) -> any {
    print("CLS-HELPER", x);
    return x * 2.0;
}

class WrapNet(torch.nn.Module) {
    def forward(self: any, x: any) -> any {
        y = torch.relu(x);
        return cls_helper(y);
    }

    def side_step(self: any, x: any) -> any {
        print("SIDE-STEP", x);
        return x * 3.0;
    }
}

glob compiled_net = torch.compile(WrapNet());
