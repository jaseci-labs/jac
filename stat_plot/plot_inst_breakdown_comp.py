import seaborn as sns
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

def plot_instruction_breakdown(df: pd.DataFrame, filename: str = "instruction_mix_absolute.png", title: str = "Instruction Mix per Benchmark (Absolute)") -> None:

    # Remove any columns that are all zeros
    df = df.loc[:, (df != 0).any(axis=0)]

    sns.set_theme(style="whitegrid")
    op_order = df.sum(axis=0).sort_values(ascending=False).index
    fig, ax = plt.subplots(figsize=(10, 6))
    bottom = np.zeros(len(df))
    for op in op_order:
        ax.bar(df.index, df[op].values, bottom=bottom, label=op)
        bottom += df[op].values

    ax.set_title(title)
    ax.set_ylabel("Instruction count")
    plt.xticks(rotation=15, ha="right")
    ax.legend(ncol=4, bbox_to_anchor=(1, 1.02), loc="lower right", frameon=True)
    plt.tight_layout()
    # Save to file
    plt.savefig(filename)