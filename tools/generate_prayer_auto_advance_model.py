#!/usr/bin/env python3
"""Generate the updatable multimodal Core ML model used by prayer auto-advance.

Input schema v5:
- features[1867]
  - 3 non-comparison progress scalars
  - 512-value normalized embedding of the last recognized spoken words
  - 512-value normalized embedding of the complete current page text
  - 840 audio values: 35 temporal slices x 24 bands over the last 7 seconds
- long_audio[1,80,16]
  - 40 seconds of coarse time/frequency context
  - compressed by three learnable convolution layers before fusion

Requires macOS and coremltools. The resulting .mlmodel is a developer seed only;
production users receive a trained compiled model from the Margaretka server.
"""

from pathlib import Path
import argparse
import numpy as np
import coremltools as ct
from coremltools.models import datatypes
from coremltools.models.neural_network import AdamParams, NeuralNetworkBuilder

INPUT_SIZE = 1867
LONG_TIME = 80
LONG_BANDS = 16
SHORT_FIRST_HIDDEN_SIZE = 512
SHORT_SECOND_HIDDEN_SIZE = 256
LONG_PROJECTION_SIZE = 32
FUSED_SIZE = SHORT_SECOND_HIDDEN_SIZE + LONG_PROJECTION_SIZE
SECOND_HIDDEN_SIZE = 128
THIRD_HIDDEN_SIZE = 32


def seeded(shape, scale, seed):
    rng = np.random.default_rng(seed)
    return rng.normal(0.0, scale, size=shape).astype(np.float32)


def add_conv(builder, *, name, input_name, input_channels, output_channels, height, width, stride, seed):
    builder.add_convolution(
        name=name,
        kernel_channels=input_channels,
        output_channels=output_channels,
        height=height,
        width=width,
        stride_height=stride,
        stride_width=stride,
        border_mode="same",
        groups=1,
        W=seeded((height, width, input_channels, output_channels), 0.05, seed),
        b=np.zeros(output_channels, dtype=np.float32),
        has_bias=True,
        input_name=input_name,
        output_name=f"{name}_linear",
    )
    builder.add_activation(
        name=f"{name}_relu",
        non_linearity="RELU",
        input_name=f"{name}_linear",
        output_name=f"{name}_output",
    )
    return f"{name}_output"


def build_model(model_version: int):
    builder = NeuralNetworkBuilder(
        input_features=[
            ("features", datatypes.Array(INPUT_SIZE)),
            ("long_audio", datatypes.Array(1, LONG_TIME, LONG_BANDS)),
        ],
        output_features=[("probabilities", datatypes.Array(2))],
    )

    # High-resolution branch: independent spoken/page text representations + 7 s audio.
    builder.add_inner_product(
        name="short_hidden1",
        W=seeded((SHORT_FIRST_HIDDEN_SIZE, INPUT_SIZE), 0.025, 11),
        b=np.zeros(SHORT_FIRST_HIDDEN_SIZE, dtype=np.float32),
        input_channels=INPUT_SIZE,
        output_channels=SHORT_FIRST_HIDDEN_SIZE,
        has_bias=True,
        input_name="features",
        output_name="short_hidden1_linear",
    )
    builder.add_activation(
        name="short_hidden1_relu",
        non_linearity="RELU",
        input_name="short_hidden1_linear",
        output_name="short_hidden1_output",
    )
    builder.add_inner_product(
        name="short_hidden2",
        W=seeded((SHORT_SECOND_HIDDEN_SIZE, SHORT_FIRST_HIDDEN_SIZE), 0.035, 53),
        b=np.zeros(SHORT_SECOND_HIDDEN_SIZE, dtype=np.float32),
        input_channels=SHORT_FIRST_HIDDEN_SIZE,
        output_channels=SHORT_SECOND_HIDDEN_SIZE,
        has_bias=True,
        input_name="short_hidden1_output",
        output_name="short_hidden2_linear",
    )
    builder.add_activation(
        name="short_hidden2_relu",
        non_linearity="RELU",
        input_name="short_hidden2_linear",
        output_name="short_hidden2_output",
    )

    # Long-context branch: 40 seconds compressed to a small learned representation.
    long_blob = add_conv(
        builder,
        name="long_conv1",
        input_name="long_audio",
        input_channels=1,
        output_channels=8,
        height=5,
        width=3,
        stride=2,
        seed=101,
    )
    long_blob = add_conv(
        builder,
        name="long_conv2",
        input_name=long_blob,
        input_channels=8,
        output_channels=12,
        height=5,
        width=3,
        stride=2,
        seed=211,
    )
    long_blob = add_conv(
        builder,
        name="long_conv3",
        input_name=long_blob,
        input_channels=12,
        output_channels=16,
        height=3,
        width=3,
        stride=2,
        seed=307,
    )
    builder.add_pooling(
        name="long_global_average",
        height=1,
        width=1,
        stride_height=1,
        stride_width=1,
        layer_type="AVERAGE",
        padding_type="VALID",
        input_name=long_blob,
        output_name="long_pooled",
        is_global=True,
    )
    builder.add_flatten(
        name="long_flatten",
        mode=0,
        input_name="long_pooled",
        output_name="long_flat",
    )
    builder.add_inner_product(
        name="long_projection",
        W=seeded((LONG_PROJECTION_SIZE, 16), 0.08, 401),
        b=np.zeros(LONG_PROJECTION_SIZE, dtype=np.float32),
        input_channels=16,
        output_channels=LONG_PROJECTION_SIZE,
        has_bias=True,
        input_name="long_flat",
        output_name="long_projection_linear",
    )
    builder.add_activation(
        name="long_projection_relu",
        non_linearity="RELU",
        input_name="long_projection_linear",
        output_name="long_projection_output",
    )

    builder.add_elementwise(
        name="fusion_concat",
        input_names=["short_hidden2_output", "long_projection_output"],
        output_name="fused_features",
        mode="CONCAT",
    )

    builder.add_inner_product(
        name="hidden2",
        W=seeded((SECOND_HIDDEN_SIZE, FUSED_SIZE), 0.045, 1009),
        b=np.zeros(SECOND_HIDDEN_SIZE, dtype=np.float32),
        input_channels=FUSED_SIZE,
        output_channels=SECOND_HIDDEN_SIZE,
        has_bias=True,
        input_name="fused_features",
        output_name="hidden2_linear",
    )
    builder.add_activation(
        name="hidden2_relu",
        non_linearity="RELU",
        input_name="hidden2_linear",
        output_name="hidden2_output",
    )
    builder.add_inner_product(
        name="hidden3",
        W=seeded((THIRD_HIDDEN_SIZE, SECOND_HIDDEN_SIZE), 0.06, 2017),
        b=np.zeros(THIRD_HIDDEN_SIZE, dtype=np.float32),
        input_channels=SECOND_HIDDEN_SIZE,
        output_channels=THIRD_HIDDEN_SIZE,
        has_bias=True,
        input_name="hidden2_output",
        output_name="hidden3_linear",
    )
    builder.add_activation(
        name="hidden3_relu",
        non_linearity="RELU",
        input_name="hidden3_linear",
        output_name="hidden3_output",
    )
    builder.add_inner_product(
        name="logits",
        W=seeded((2, THIRD_HIDDEN_SIZE), 0.08, 4001),
        b=np.array([1.0, -1.0], dtype=np.float32),
        input_channels=THIRD_HIDDEN_SIZE,
        output_channels=2,
        has_bias=True,
        input_name="hidden3_output",
        output_name="logits_output",
    )
    builder.add_softmax(
        name="probabilities_softmax",
        input_name="logits_output",
        output_name="probabilities",
    )

    builder.make_updatable([
        "short_hidden1",
        "short_hidden2",
        "long_conv1",
        "long_conv2",
        "long_conv3",
        "long_projection",
        "hidden2",
        "hidden3",
        "logits",
    ])
    builder.set_categorical_cross_entropy_loss(name="classification_loss", input="probabilities")
    builder.set_adam_optimizer(AdamParams(lr=0.002, batch=1))
    builder.set_epochs(3)

    spec = builder.spec
    spec.description.input[0].shortDescription = "1867 direct multimodal features: independent spoken/page embeddings plus 7-second audio."
    spec.description.input[1].shortDescription = "40-second coarse audio context [1,80,16] compressed by learnable convolutions."
    spec.description.output[0].shortDescription = "[stay, advance] probabilities."
    spec.description.trainingInput[0].shortDescription = "Multimodal v5 direct-text and 7-second short-audio features."
    spec.description.trainingInput[1].shortDescription = "Multimodal v5 long audio context."
    spec.description.trainingInput[2].shortDescription = "0 = stay, 1 = advance."

    model = ct.models.MLModel(spec)
    model.author = "Margaretka"
    model.short_description = "Updatable on-device multimodal prayer auto-advance classifier"
    model.user_defined_metadata["modelVersion"] = str(model_version)
    model.user_defined_metadata["featureSchemaVersion"] = "5"
    return model


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="PrayerAutoAdvance.mlmodel")
    parser.add_argument("--model-version", type=int, default=5)
    args = parser.parse_args()

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    build_model(args.model_version).save(str(output))
    print(output.resolve())


if __name__ == "__main__":
    main()
