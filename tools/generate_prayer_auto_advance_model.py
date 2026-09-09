#!/usr/bin/env python3
"""Generate the updatable audio-primary Core ML model used by prayer auto-advance.

Feature schema v8 uses ONE Core ML input so every trainable layer sits on a plain
backpropagation path to the loss. Core ML's legacy updatable neural-network validator
rejects CONCAT between an updatable layer and the loss.

The app concatenates locally, before Core ML:
- 3 auxiliary scalars
- 512 spoken-text embedding
- 512 page-text embedding
- 2400 short-audio features (10 s, 50 x 48, 16 kHz analysis)
- 3840 long-audio features (60 s, 120 x 32, 16 kHz analysis)
Total: 7267 float values, of which 6240 (~86%) are audio.

Model v10 doubles the audio sampling rate from 8 kHz to 16 kHz and doubles the
spectral-band representation so the network can use the additional 4-8 kHz content.
The stable v9 personalization strategy is retained: only hidden4, hidden5 and logits
are updatable on device.
"""

from pathlib import Path
import argparse
import shutil
import numpy as np
import coremltools as ct
from coremltools.models import datatypes
from coremltools.models.neural_network import AdamParams, NeuralNetworkBuilder

SCALAR_SIZE = 3
TEXT_EMBEDDING_SIZE = 512
SHORT_AUDIO_SIZE = 50 * 48
LONG_AUDIO_SIZE = 120 * 32
INPUT_SIZE = SCALAR_SIZE + 2 * TEXT_EMBEDDING_SIZE + SHORT_AUDIO_SIZE + LONG_AUDIO_SIZE
HIDDEN_SIZES = [1536, 1024, 512, 256, 64]
MODEL_VERSION = 10
SCHEMA_VERSION = 8
UPDATABLE_LAYERS = ["hidden4", "hidden5", "logits"]


def seeded(shape, scale, seed):
    rng = np.random.default_rng(seed)
    return rng.normal(0.0, scale, size=shape).astype(np.float32)


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
        input_features=[("features", datatypes.Array(INPUT_SIZE))],
        output_features=[("probabilities", datatypes.Array(2))],
    )

    blob = "features"
    input_size = INPUT_SIZE
    configs = [
        ("hidden1", 1536, 0.015, 11),
        ("hidden2", 1024, 0.020, 1009),
        ("hidden3", 512, 0.028, 2017),
        ("hidden4", 256, 0.038, 3001),
        ("hidden5", 64, 0.055, 3503),
    ]
    for name, output_size, scale, seed in configs:
        blob = add_dense_relu(
            builder,
            name=name,
            input_name=blob,
            input_size=input_size,
            output_size=output_size,
            scale=scale,
            seed=seed,
        )
        input_size = output_size

    builder.add_inner_product(
        name="logits",
        W=seeded((2, input_size), 0.08, 4001),
        b=np.array([1.0, -1.0], dtype=np.float32),
        input_channels=input_size,
        output_channels=2,
        has_bias=True,
        input_name=blob,
        output_name="logits_output",
    )
    builder.add_softmax(
        name="probabilities_softmax",
        input_name="logits_output",
        output_name="probabilities",
    )

    builder.make_updatable(UPDATABLE_LAYERS)
    builder.set_categorical_cross_entropy_loss(name="classification_loss", input="probabilities")
    builder.set_adam_optimizer(AdamParams(lr=0.0005, batch=1))
    builder.set_epochs(3)

    spec = builder.spec
    spec.description.input[0].shortDescription = (
        "7267 local features: 3 scalars + 512 spoken embedding + 512 page embedding + "
        "2400 short-audio + 3840 long-audio values."
    )
    spec.description.output[0].shortDescription = "[stay, advance] probabilities."
    spec.description.trainingInput[0].shortDescription = "16 kHz audio-primary multimodal feature schema v8."
    spec.description.trainingInput[1].shortDescription = "0 = stay, 1 = advance."

    model = ct.models.MLModel(spec)
    model.author = "Margaretka"
    model.short_description = "Updatable on-device 16 kHz audio-primary prayer auto-advance classifier"
    model.user_defined_metadata["modelVersion"] = str(model_version)
    model.user_defined_metadata["featureSchemaVersion"] = str(SCHEMA_VERSION)
    return model


def parameter_count():
    sizes = [INPUT_SIZE] + HIDDEN_SIZES + [2]
    return sum(a * b + b for a, b in zip(sizes, sizes[1:]))


def updatable_parameter_count():
    # hidden4: 512 -> 256, hidden5: 256 -> 64, logits: 64 -> 2
    sizes = [(512, 256), (256, 64), (64, 2)]
    return sum(a * b + b for a, b in sizes)


def self_test(output: Path, model_version: int):
    spec = ct.models.utils.load_spec(str(output))
    metadata = spec.description.metadata.userDefined
    inputs = [(x.name, list(x.type.multiArrayType.shape)) for x in spec.description.input]
    updatable = [layer.name for layer in spec.neuralNetwork.layers if layer.isUpdatable]
    params = parameter_count()
    update_params = updatable_parameter_count()
    size_bytes = output.stat().st_size

    if metadata.get("modelVersion") != str(model_version):
        raise RuntimeError(f"modelVersion mismatch: {metadata.get('modelVersion')!r}")
    if metadata.get("featureSchemaVersion") != str(SCHEMA_VERSION):
        raise RuntimeError(f"featureSchemaVersion mismatch: {metadata.get('featureSchemaVersion')!r}")
    if inputs != [("features", [INPUT_SIZE])]:
        raise RuntimeError(f"Unexpected inputs: {inputs}")
    if updatable != UPDATABLE_LAYERS:
        raise RuntimeError(f"Expected updatable layers {UPDATABLE_LAYERS}, found {updatable}")
    if size_bytes < 40_000_000:
        raise RuntimeError(
            f"Generated model is only {size_bytes} bytes; expected a v10 model larger than 40 MB. "
            "Do not add this file to Xcode."
        )

    compiled_dir = None
    try:
        compiled_dir = ct.models.utils.compile_model(str(output))
    finally:
        if compiled_dir:
            shutil.rmtree(compiled_dir, ignore_errors=True)

    print(f"modelVersion: {model_version}")
    print(f"featureSchemaVersion: {SCHEMA_VERSION}")
    print(f"total parameters: {params:,}")
    print(f"updatable parameters: {update_params:,}")
    print(f"Float32 parameter payload: {params * 4 / 1024 / 1024:.2f} MiB")
    print(f"saved .mlmodel size: {size_bytes / 1024 / 1024:.2f} MiB")
    print(f"inputs: features[{INPUT_SIZE}]")
    print(f"hidden sizes: {HIDDEN_SIZES}")
    print(f"updatable layers: {', '.join(updatable)}")
    print("SELF-TEST: OK")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="PrayerAutoAdvance.mlmodel")
    parser.add_argument("--model-version", type=int, default=MODEL_VERSION)
    args = parser.parse_args()

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    build_model(args.model_version).save(str(output))
    self_test(output, args.model_version)
    print(output.resolve())


if __name__ == "__main__":
    main()
