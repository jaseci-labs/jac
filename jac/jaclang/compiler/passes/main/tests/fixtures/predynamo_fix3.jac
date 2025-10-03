import torch;
class Cfg {
    def __init__(self: Cfg, max_position_embeddings: Any = 8, has_original: Any = False) {
        self.max_position_embeddings = max_position_embeddings;
        if has_original {
            self.original_max_position_embeddings = (max_position_embeddings // 2);
        }
    }
}
class ToyModel(torch.nn.Module) {
    def __init__(self: ToyModel, cfg: Cfg) {
        super.init();
        self.config = cfg;
        self.long_inv_freq = torch.tensor([10.0, 20.0, 30.0]);
        self.original_inv_freq = torch.tensor([1.0, 2.0, 3.0]);
    }
    def rope_init_fn(self: ToyModel, cfg: Any, device: Any, seq_len: int) {
        return (torch.arange(1, 4, dtype=torch.float32, device=device), None);
    }
    def _longrope_frequency_update(
        self: ToyModel,
        position_ids: Any,
        device: Any = 'cpu'
    ) {
        seq_len = (torch.max(position_ids) + 1);
        if hasattr(self.config, 'original_max_position_embeddings') {
            original_max_position_embeddings = self.config.original_max_position_embeddings;
        } else {
            original_max_position_embeddings = self.config.max_position_embeddings;
        }
        if (seq_len > original_max_position_embeddings) {
            self.register_buffer('inv_freq', self.long_inv_freq, persistent=False);
        } else {
            self.register_buffer(
                'inv_freq',
                self.original_inv_freq.to(device),
                persistent=False
            );
        }
        return self.inv_freq;
    }
}

