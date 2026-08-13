Abstract
Lithium-ion battery state estimation traditionally relies on electrical
measurements that degrade over time and require costly hardware.
We present CoBas (Contactless Battery Sensing), a multimodal
pipeline for contactless state of charge (SoC) classification using
only a commercial smartphone. CoBas emits near-ultrasonic chirps
from a laptop speaker, captures the acoustic and visual response
on an iPhone, and fuses STFT spectral features with synchronized
video frames using a dual-stream ResNet-18 with late fusion. Eval-
uated on Samsung 21700 lithium-ion cells at 0%, 50%, and 100%
SoC, the fused model achieves 100% classification accuracy on held-
out test videos. These results provide preliminary evidence that
near-ultrasonic frequencies carry discriminative information upon
interaction with Li-ion cells, establishing contactless battery diag-
nostics as a feasible pathway for low-cost smart energy monitoring.
Keywords
State of charge (SoC), Lithium-ion batteries, Feature Fusion, Multi-
modal Learning

Figure 1: CoBas system overview.
1
Introduction
Lithium-ion batteries power everything from consumer electronics
to electric vehicles, making reliable state estimation critical for safe
and efficient operation. Traditional approaches rely on electrical
measurements such as terminal voltage and current integration.
Model-driven methods like Coulomb counting and Kalman filters
perform well under stable conditions but degrade under dynamic
loading and long-term cycling [3, 5]. Data-driven electrical features
cannot directly capture internal structural changes as the cell ages,
causing feature drift as state of health declines [4].
Ultrasonic sensing offers a physically grounded alternative. Elec-
trochemical processes during lithiation and delithiation induce mea-
surable mechanical changes within the cell, manifest as variations
in acoustic wave propagation [7–9]. However, existing systems
depend on high-fidelity oscilloscopes and physical contact, making
them impractical for embedded applications [1].
As shown in Figure 1, we present CoBas (Contactless Battery
Sensing), a multimodal pipeline for contactless SoC classification us-
ing only a commercial smartphone [2]. CoBas fuses near-ultrasonic
STFT features with synchronized video frames via dual-stream
ResNet-18 with late fusion--no specialized hardware, no physical
contact required

A MacBook Pro (M1, 2020) emits chirp signals spanning 15–19.2 kHz
toward Samsung 21700 lithium-ion cells at 0%, 50%, and 100% SoC,
while an iPhone 14 Pro captures acoustic and visual responses
simultaneously without physical contact.
Figure 3: CoBas pipeline: chirp emission, beacon detection,
window segmentation, and parallel acoustic and optical pro-
cessing streams.
As shown in Figure 3, a beacon encoding protocol embedded in
each chirp enables automatic boundary detection, eliminating tim-
ing variability and achieving a recording length standard deviation
of 0.003 ± 0.002 s across trials. Each recording is segmented into
aligned 2-second windows, with every audio segment paired to its
corresponding video frame. STFT representations are computed
and cropped to the 15–19.2 kHz band, preserving linear frequency
resolution critical for detecting fine-grained spectral shifts [6].
CoBas processes each modality through an independent ResNet-
18 stream before late fusion for joint SoC classification. Acoustic
features encode internal electrochemical state while visual features
stabilize against setup variability [10].
3
Results
The dataset is split 70/20/10 across training, validation, and held-out
test videos with SoC treated as a three-class classification problem.
The fused audio-visual model achieves 100% accuracy on held-
out test videos, as shown in Figure 2(b). Audio-only STFT features
show partial class separation, confirming near-ultrasonic spectral
content carries discriminative SoC information [6]. Mel spectro-
gram features show increased class overlap as perceptual compres-
sion attenuates high-frequency structure. Visual features alone do
not encode SoC. When fused with STFT features, visual cues re-
duce sensitivity to setup variability and yield the most separable
embeddings across all modalities, as shown in Figure 2(a).
Unsupervised STFT embeddings yield a Silhouette Score of 0.1597
and Davies-Bouldin Index of 2.1179, indicating weak but non-random
structure that does not align with SoC labels without supervision.
Supervised multimodal fusion is therefore necessary to reliably
map spectral patterns to battery state. These results establish con-
tactless SoC classification as feasible on commodity smartphones.
Future work will extend to diverse battery chemistries, dynamic
conditions, and continuous SoC regression.
