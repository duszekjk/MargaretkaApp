#!/usr/bin/env python3
"""Generate and verify the updatable multimodal Core ML prayer auto-advance seed.

Input schema v6:
- scalars[3]
- spoken_embedding[512]
- page_embedding[512]
- short_audio[1200]: 50 x 24 over the last 10 seconds, projected to 1024
- long_audio[1,120,16]: 60 seconds, convolutional branch projected to 128

The generator intentionally performs a strict post-save self-test. A valid v6 seed
contains roughly 2.56M Float32 trainable parameters, so a tiny/stub .mlmodel must
never silently make it into Xcode.
"""

from pathlib import Path
import argparse
import sys
import numpy as np
import coremltools as ct
from coremltools.models import datatypes
from coremltools.models.neural_network import AdamParams, NeuralNetworkBuilder

SCALAR_SIZE = 3
TEXT_EMBEDDING_SIZE = 512
SHORT_AUDIO_SIZE = 1200
LONG_TIME = 120
LONG_BANDS = 16
SHORT_AUDIO_PROJECTION_SIZE = 1024
SCALAR_PROJECTION_SIZE = 16
LONG_PROJECTION_SIZE = 128
FUSED_SIZE = (
    SHORT_AUDIO_PROJECTION_SIZE
    + LONG_PROJECTION_SIZE
    + TEXT_EMBEDDING_SIZE
    + TEXT_EMBEDDING_SIZE
    + SCALAR_PROJECTION_SIZE
)
FUSION_HIDDEN_SIZE = 512
SECOND_HIDDEN_SIZE = 256
THIRD_HIDDEN_SIZE = 128
FOURTH_HIDDEN_SIZE = 32
FEATURE_SCHEMA_VERSION = 6

TRAINABLE_PARAMETER_COUNT = (
    SHORT_AUDIO_SIZE * SHORT_AUDIO_PROJECTION_SIZE + SHORT_AUDIO_PROJECTION_SIZE
    + 5 * 3 * 1 * 16 + 16
    + 5 * 3 * 16 * 32 + 32
    + 3 * 3 * 32 * 64 + 64
    + 64 * LONG_PROJECTION_SIZE + LONG_PROJECTION_SIZE
    + SCALAR_SIZE * SCALAR_PROJECTION_SIZE + SCALAR_PROJECTION_SIZE
    + FUSED_SIZE * FUSION_HIDDEN_SIZE + FUSION_HIDDEN_SIZE
    + FUSION_HIDDEN_SIZE * SECOND_HIDDEN_SIZE + SECOND_HIDDEN_SIZE
    + SECOND_HIDDEN_SIZE * THIRD_HIDDEN_SIZE + THIRD_HIDDEN_SIZE
    + THIRD_HIDDEN_SIZE * FOURTH_HIDDEN_SIZE + FOURTH_HIDDEN_SIZE
    + FOURTH_HIDDEN_SIZE * 2 + 2
)
EXPECTED_INPUT_NAMES = [
    "scalars",
    "spoken_embedding",
    "page_embedding",
    "short_audio",
    "long_audio",
]
# 2.56M Float32 parameters alone are ~9.75 MiB. Leave some tolerance for how
# coremltools serializes the protobuf, but reject anything remotely stub-sized.
MINIMUM_MODEL_BYTES = 8 * 1024 * 1024


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
        W=seeded((height, width, input_channels, output_channels), 0.045, seed),
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


def add_dense_relu(builder, *, name, input_name, input_size, output_size, scale, seed):
    builder.add_inner_product(
        name=name,
        W=seeded((output_size, input_size), scale, seed),
        b=np.zeros(output_size, dtype=np.float32),
        input_channels=input_size,
        output_channels=output_size,
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
            ("scalars", datatypes.Array(SCALAR_SIZE)),
            ("spoken_embedding", datatypes.Array(TEXT_EMBEDDING_SIZE)),
            ("page_embedding", datatypes.Array(TEXT_EMBEDDING_SIZE)),
            ("short_audio", datatypes.Array(SHORT_AUDIO_SIZE)),
            ("long_audio", datatypes.Array(1, LONG_TIME, LONG_BANDS)),
        ],
        output_features=[("probabilities", datatypes.Array(2))],
    )

    short_audio_blob = add_dense_relu(
        builder,
        name="short_audio_projection",
        input_name="short_audio",
        input_size=SHORT_AUDIO_SIZE,
        output_size=SHORT_AUDIO_PROJECTION_SIZE,
        scale=0.025,
        seed=11,
    )

    long_blob = add_conv(
        builder,
        name="long_conv1",
        input_name="long_audio",
        input_channels=1,
        output_channels=16,
        height=5,
        width=3,
        stride=2,
        seed=101,
    )
    long_blob = add_conv(
        builder,
        name="long_conv2",
        input_name=long_blob,
        input_channels=16,
        output_channels=32,
        height=5,
        width=3,
        stride=2,
        seed=211,
    )
    long_blob = add_conv(
        builder,
        name="long_conv3",
        input_name=long_blob,
        input_channels=32,
        output_channels=64,
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
    long_projection_blob = add_dense_relu(
        builder,
        name="long_projection",
        input_name="long_flat",
        input_size=64,
        output_size=LONG_PROJECTION_SIZE,
        scale=0.06,
        seed=401,
    )

    scalar_blob = add_dense_relu(
        builder,
        name="scalar_projection",
        input_name="scalars",
        input_size=SCALAR_SIZE,
        output_size=SCALAR_PROJECTION_SIZE,
        scale=0.15,
        seed=503,
    )

    builder.add_elementwise(
        name="fusion_concat",
        input_names=[
            short_audio_blob,
            long_projection_blob,
            "spoken_embedding",
            "page_embedding",
            scalar_blob,
        ],
        output_name="fused_features",
        mode="CONCAT",
    )

    fusion_blob = add_dense_relu(
        builder,
        name="fusion_hidden1",
        input_name="fused_features",
        input_size=FUSED_SIZE,
        output_size=FUSION_HIDDEN_SIZE,
        scale=0.022,
        seed=1009,
    )
    fusion_blob = add_dense_relu(
        builder,
        name="fusion_hidden2",
        input_name=fusion_blob,
        input_size=FUSION_HIDDEN_SIZE,
        output_size=SECOND_HIDDEN_SIZE,
        scale=0.035,
        seed=2017,
    )
    fusion_blob = add_dense_relu(
        builder,
        name="fusion_hidden3",
        input_name=fusion_blob,
        input_size=SECOND_HIDDEN_SIZE,
        output_size=THIRD_HIDDEN_SIZE,
        scale=0.045,
        seed=3001,
    )
    fusion_blob = add_dense_relu(
        builder,
        name="fusion_hidden4",
        input_name=fusion_blob,
        input_size=THIRD_HIDDEN_SIZE,
        output_size=FOURTH_HIDDEN_SIZE,
        scale=0.06,
        seed=3503,
    )

    builder.add_inner_product(
        name="logits",
        W=seeded((2, FOURTH_HIDDEN_SIZE), 0.08, 4001),
        b=np.array([1.0, -1.0], dtype=np.float32),
        input_channels=FOURTH_HIDDEN_SIZE,
        output_channels=2,
        has_bias=True,
        input_name=fusion_blob,
        output_name="logits_output",
    )
    builder.add_softmax(
        name="probabilities_softmax",
        input_name="logits_output",
        output_name="probabilities",
    )

    builder.make_updatable([
        "short_audio_projection",
        "long_conv1",
        "long_conv2",
        "long_conv3",
        "long_projection",
        "scalar_projection",
        "fusion_hidden1",
        "fusion_hidden2",
        "fusion_hidden3",
        "fusion_hidden4",
        "logits",
    ])
    builder.set_categorical_cross_entropy_loss(name="classification_loss", input="probabilities")
    builder.set_adam_optimizer(AdamParams(lr=0.002, batch=1))
    builder.set_epochs(3)

    spec = builder.spec
    spec.description.input[0].shortDescription = "Three auxiliary timing/text-count scalars."
    spec.description.input[1].shortDescription = "512-value embedding of the last recognized spoken words."
    spec.description.input[2].shortDescription = "512-value embedding of the complete current page text."
    spec.description.input[3].shortDescription = "1200 high-resolution acoustic features from the last 10 seconds."
    spec.description.input[4].shortDescription = "60-second coarse audio context [1,120,16]."
    spec.description.output[0].shortDescription = "[stay, advance] probabilities."
    spec.description.trainingInput[0].shortDescription = "Auxiliary scalars."
    spec.description.trainingInput[1].shortDescription = "Recognized-speech embedding."
    spec.description.trainingInput[2].shortDescription = "Current-page embedding."
    spec.description.trainingInput[3].shortDescription = "Ten-second high-resolution audio representation."
    spec.description.trainingInput[4].shortDescription = "Sixty-second long audio representation."
    spec.description.trainingInput[5].shortDescription = "0 = stay, 1 = advance."

    model = ct.models.MLModel(spec)
    model.author = "Margaretka"
    model.short_description = "Updatable on-device audio-primary prayer auto-advance classifier"
    model.user_defined_metadata["modelVersion"] = str(model_version)
    model.user_defined_metadata["featureSchemaVersion"] = str(FEATURE_SCHEMA_VERSION)
    return model


def verify_saved_model(output: Path, expected_model_version: int):
    if not output.is_file():
        raise RuntimeError(f"Generator did not create a regular .mlmodel file: {output}")

    size_bytes = output.stat().st_size
    if size_bytes < MINIMUM_MODEL_BYTES:
        raise RuntimeError(
            f"Generated model is only {size_bytes:,} bytes; expected at least "
            f"{MINIMUM_MODEL_BYTES:,} bytes for {TRAINABLE_PARAMETER_COUNT:,} Float32 parameters. "
            "Do not add this file to Xcode."
        )

    loaded = ct.models.MLModel(str(output))
    metadata = loaded.user_defined_metadata
    model_version = metadata.get("modelVersion")
    schema_version = metadata.get("featureSchemaVersion")
    if model_version != str(expected_model_version):
        raise RuntimeError(
            f"modelVersion mismatch after reload: {model_version!r}, expected {expected_model_version}."
        )
    if schema_version != str(FEATURE_SCHEMA_VERSION):
        raise RuntimeError(
            f"featureSchemaVersion mismatch after reload: {schema_version!r}, expected {FEATURE_SCHEMA_VERSION}."
        )

    spec = loaded.get_spec()
    input_names = [item.name for item in spec.description.input]
    if input_names != EXPECTED_INPUT_NAMES:
        raise RuntimeError(
            f"Input schema mismatch after reload: {input_names!r}, expected {EXPECTED_INPUT_NAMES!r}."
        )

    updatable = [layer.name for layer in spec.neuralNetwork.layers if layer.isUpdatable]
    expected_updatable = {
        "short_audio_projection",
        "long_conv1",
        "long_conv2",
        "long_conv3",
        "long_projection",
        "scalar_projection",
        "fusion_hidden1",
        "fusion_hidden2",
        "fusion_hidden3",
        "fusion_hidden4",
        "logits",
    }
    missing_updatable = expected_updatable.difference(updatable)
    if missing_updatable:
        raise RuntimeError(
            f"Missing updatable layers after reload: {sorted(missing_updatable)!r}."
        )

    print(f"modelVersion: {model_version}")
    print(f"featureSchemaVersion: {schema_version}")
    print(f"trainable parameters: {TRAINABLE_PARAMETER_COUNT:,}")
    print(f"Float32 parameter payload: {TRAINABLE_PARAMETER_COUNT * 4 / (1024 * 1024):.2f} MiB")
    print(f"saved .mlmodel size: {size_bytes / (1024 * 1024):.2f} MiB ({size_bytes:,} bytes)")
    print(f"inputs: {', '.join(input_names)}")
    print(f"updatable layers: {len(updatable)}")
    print("SELF-TEST: OK")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="PrayerAutoAdvance.mlmodel")
    parser.add_argument("--model-version", type=int, default=6)
    args = parser.parse_args()

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    try:
        build_model(args.model_version).save(str(output))
        verify_saved_model(output, args.model_version)
    except Exception as error:
        print(f"SELF-TEST: FAILED: {error}", file=sys.stderr)
        raise

    print(output.resolve())


if __name__ == "__main__":
    main()
