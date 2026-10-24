glob:pub ZS_NEXT_IN: int = 0,
     ZS_AVAIL_IN: int = 8,
     ZS_TOTAL_IN: int = 16,
     ZS_NEXT_OUT: int = 24,
     ZS_AVAIL_OUT: int = 32,
     ZS_TOTAL_OUT: int = 40,
     Z_STREAM_SIZE: int = 112;

def:pub zs_load_total(addr: int) -> int;
