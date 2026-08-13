#!/usr/bin/env python3
"""Generate the small updatable Core ML model used by prayer auto-advance.

Requires macOS and coremltools. The resulting .mlmodel is a developer seed only;
production users receive a trained compiled model from the Margaretka server.
"""

from pathlib import Path
import argparse
import numpy as np
import coremltools as ct
from coremltools.models import datatypes
from coremltools.models.neural_network import AdamParams, NeuralNetworkBuilder

INPUT_SIZE = 10
HIDDEN_SIZE = 32
SECOND_HIDDEN_SIZE = 16


def seeded(shape, scale, seed):
    rng = np.random.default_rng(seed)
    return rng.normal(0.0, scale, size=shape).astype(np.float32)


def build_model(model_version: int):
    builder = NeuralNetworkBuilder(
        input_features=[("features", datatypes.Array(INPUT_SIZE))],
        output_features=[("probabilities", datatypes.Array(2))],
    )

    builder.add_inner_product(
        name="hidden1",
        W=seeded((HIDDEN_SIZE, INPUT_SIZE), 0.12, 11),
        b=np.zeros(HIDDEN_SIZE, dtype=np.float32),
        input_channels=INPUT_SIZE,
        output_channels=HIDDEN_SIZE,
        has_bias=True,
        input_name="features",
        output_name="hidden1_linear",
    )
    builder.add_activation(
        name="hidden1_relu",
        non_linearity="RELU",
        input_name="hidden1_linear",
        output_name="hidden1_output",
    )
    builder.add_inner_product(
        name="hidden2",
        W=seeded((SECOND_HIDDEN_SIZE, HIDDEN_SIZE), 0.10, 1009),
        b=np.zeros(SECOND_HIDDEN_SIZE, dtype=np.float32),
        input_channels=HIDDEN_SIZE,
        output_channels=SECOND_HIDDEN_SIZE,
        has_bias=True,
        input_name="hidden1_output",
        output_name="hidden2_linear",
    )
    builder.add_activation(
        name="hidden2_relu",
        non_linearity="RELU",
        input_name="hidden2_linear",
        output_name="hidden2_output",
    )
    builder.add_inner_product(
        name="logits",
        W=seeded((2, SECOND_HIDDEN_SIZE), 0.08, 4001),
        b=np.array([1.0, -1.0], dtype=np.float32),
        input_channels=SECOND_HIDDEN_SIZE,
        output_channels=2,
        has_bias=True,
        input_name="hidden2_output",
        output_name="logits_output",
    )
    builder.add_softmax(
        name="probabilities_softmax",
        input_name="logits_output",
        output_name="probabilities",
    )

    builder.make_updatable(["hidden1", "hidden2", "logits"])
    builder.set_categorical_cross_entropy_loss(name="classification_loss", input="probabilities")
    builder.set_adam_optimizer(AdamParams(lr=0.005, batch=8))
    builder.set_epochs(3)

    spec = builder.spec
    spec.description.input[0].shortDescription = "Ten normalized prayer-progress features."
    spec.description.output[0].shortDescription = "[stay, advance] probabilities."
    spec.description.trainingInput[0].shortDescription = "Ten normalized prayer-progress features."
    spec.description.trainingInput[1].shortDescription = "0 = stay, 1 = advance."

    model = ct.models.MLModel(spec)
    model.author = "Margaretka"
    model.short_description = "Updatable on-device prayer auto-advance classifier"
    model.user_defined_metadata["modelVersion"] = str(model_version)
    model.user_defined_metadata["featureSchemaVersion"] = "1"
    return model


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="PrayerAutoAdvance.mlmodel")
    parser.add_argument("--model-version", type=int, default=1)
    args = parser.parse_args()

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    build_model(args.model_version).save(str(output))
    print(output.resolve())


if __name__ == "__main__":
    main()
