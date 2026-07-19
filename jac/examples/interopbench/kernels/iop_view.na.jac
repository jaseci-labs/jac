obj Sample {
    has value: int,
        weight: int;
}


glob retained_values: list[int] = [],
     retained_samples: list[Sample] = [];


def produce_views(count: int) -> tuple[list[int], list[Sample]] {
    values: list[int] = [];
    samples: list[Sample] = [];
    for i in range(count) {
        value = (i * 17 + 3) % 1009;
        values.append(value);
        samples.append(Sample(value=value, weight=(value * 13 + i) % 4093));
    }
    retained_values = values;
    retained_samples = samples;
    return (retained_values, retained_samples);
}
