#!/usr/bin/env python3
"""Generate the fully updatable V12 prayer auto-advance Core ML model.

Feature schema v9 keeps ONE flattened Core ML input so every parameterized layer
remains on a plain backpropagation path to the loss. The app concatenates locally:
- 4 scalar features: elapsed, spoken-word count, page-word count, last speech-segment end time
- 512 spoken-text embedding
- 512 full-page embedding
- 2400 short-audio features (10 s, 50 x 48)
- 3840 long-audio features (60 s, 120 x 32)
Total: 7268 float values.

V12 changes the audio semantics, not the dense architecture. Audio is produced by a
shared fixed-grid 16 kHz streaming spectral front end: 40 ms Hann windows on a 20 ms
hop. The 48-band representation is computed once with Accelerate/vDSP and reused by
both the 10 s and 60 s views; the long branch resamples those same 48 bands to 32.
"""

from pathlib import Path
import argparse
import shutil
import numpy as np
import coremltools as ct
from coremltools.models import datatypes
from coremltools.models.neural_network import AdamParams, NeuralNetworkBuilder

SCALAR_SIZE = 4
TEXT_EMBEDDING_SIZE = 512
SHORT_AUDIO_SIZE = 50 * 48
LONG_AUDIO_SIZE = 120 * 32
INPUT_SIZE = SCALAR_SIZE + 2 * TEXT_EMBEDDING_SIZE + SHORT_AUDIO_SIZE + LONG_AUDIO_SIZE
HIDDEN_SIZES = [1536, 1024, 512, 256, 64]
MODEL_VERSION = 12
SCHEMA_VERSION = 9
PARAMETER_LAYERS = ["hidden1", "hidden2", "hidden3", "hidden4", "hidden5", "logits"]
UPDATABLE_LAYERS = PARAMETER_LAYERS.copy()


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
    builder.set_adam_optimizer(AdamParams(lr=0.00001, batch=1))
    builder.set_epochs(3)

    spec = builder.spec
    spec.description.input[0].shortDescription = (
        "7268 local features: 4 scalars + 512 spoken embedding + 512 page embedding + "
        "2400 short-audio + 3840 long-audio values."
    )
    spec.description.output[0].shortDescription = "[stay, advance] probabilities."
    spec.description.trainingInput[0].shortDescription = (
        "16 kHz fixed-grid streaming spectral multimodal feature schema v9."
    )
    spec.description.trainingInput[1].shortDescription = "0 = stay, 1 = advance."

    model = ct.models.MLModel(spec)
    model.author = "Margaretka"
    model.short_description = "Fully updatable V12 on-device streaming-spectral prayer auto-advance classifier"
    model.user_defined_metadata["modelVersion"] = str(model_version)
    model.user_defined_metadata["featureSchemaVersion"] = str(SCHEMA_VERSION)
    model.user_defined_metadata["audioFrontEnd"] = "fixed-grid-16khz-40ms-window-20ms-hop-vdsp"
    model.user_defined_metadata["updatableLayers"] = ",".join(UPDATABLE_LAYERS)
    model.user_defined_metadata["allParameterizedLayersUpdatable"] = "true"
    model.user_defined_metadata["adamLearningRate"] = "0.00001"
    return model


def parameter_count():
    sizes = [INPUT_SIZE] + HIDDEN_SIZES + [2]
    return sum(a * b + b for a, b in zip(sizes, sizes[1:]))


def updatable_parameter_count():
    return parameter_count()


def self_test(output: Path, model_version: int):
    spec = ct.models.utils.load_spec(str(output))
    metadata = spec.description.metadata.userDefined
    inputs = [(x.name, list(x.type.multiArrayType.shape)) for x in spec.description.input]
    updatable = [layer.name for layer in spec.neuralNetwork.layers if layer.isUpdatable]
    parameter_layers = [
        layer.name
        for layer in spec.neuralNetwork.layers
        if layer.WhichOneof("layer") == "innerProduct"
    ]
    params = parameter_count()
    update_params = updatable_parameter_count()
    size_bytes = output.stat().st_size

    if metadata.get("modelVersion") != str(model_version):
        raise RuntimeError(f"modelVersion mismatch: {metadata.get('modelVersion')!r}")
    if metadata.get("featureSchemaVersion") != str(SCHEMA_VERSION):
        raise RuntimeError(f"featureSchemaVersion mismatch: {metadata.get('featureSchemaVersion')!r}")
    if metadata.get("audioFrontEnd") != "fixed-grid-16khz-40ms-window-20ms-hop-vdsp":
        raise RuntimeError(f"Unexpected audio front end metadata: {metadata.get('audioFrontEnd')!r}")
    if metadata.get("allParameterizedLayersUpdatable") != "true":
        raise RuntimeError("Model metadata does not declare full parameter training")
    if metadata.get("adamLearningRate") != "0.00001":
        raise RuntimeError(f"Unexpected Adam learning rate metadata: {metadata.get('adamLearningRate')!r}")
    if inputs != [("features", [INPUT_SIZE])]:
        raise RuntimeError(f"Unexpected inputs: {inputs}")
    if parameter_layers != PARAMETER_LAYERS:
        raise RuntimeError(f"Unexpected parameterized layers: {parameter_layers}")
    if updatable != PARAMETER_LAYERS:
        raise RuntimeError(
            "Every parameterized layer must be updatable; "
            f"parameter layers={parameter_layers}, updatable={updatable}"
        )
    if update_params != params:
        raise RuntimeError(f"Only {update_params:,} of {params:,} parameters are trainable")
    if size_bytes < 40_000_000:
        raise RuntimeError(
            f"Generated model is only {size_bytes} bytes; expected a V12 model larger than 40 MB. "
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
    print(f"parameterized layers: {', '.join(parameter_layers)}")
    print(f"updatable layers: {', '.join(updatable)}")
    print("audio front end: fixed-grid 16 kHz / 40 ms window / 20 ms hop / vDSP")
    print("adam learning rate: 0.00001")
    print("SELF-TEST: OK")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="PrayerAutoAdvance.mlmodel")
    parser.add_argument("--model-version", type=int, default=MODEL_VERSION)
    args = parser.parse_args()
    if args.model_version != MODEL_VERSION:
        parser.error(f"V12 generator requires --model-version {MODEL_VERSION}")

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    build_model(args.model_version).save(str(output))
    self_test(output, args.model_version)
    print(output.resolve())


if __name__ == "__main__":
    main()
