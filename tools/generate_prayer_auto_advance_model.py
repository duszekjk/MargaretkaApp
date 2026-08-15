#!/usr/bin/env python3
"""Generate the updatable multimodal Core ML model used by prayer auto-advance.

Input schema v2:
- 8 prayer-progress/text-alignment scalars
- 512-value normalized sentence embedding of the recognized text
- 600 audio values: 25 temporal slices x 24 voice-frequency bands over 5 seconds

Requires macOS and coremltools. The resulting .mlmodel is a developer seed only;
production users receive a trained compiled model from the Margaretka server.
"""

from pathlib import Path
import argparse
import numpy as np
import coremltools as ct
from coremltools.models import datatypes
from coremltools.models.neural_network import AdamParams, NeuralNetworkBuilder

INPUT_SIZE = 1120
HIDDEN_SIZE = 256
SECOND_HIDDEN_SIZE = 128
THIRD_HIDDEN_SIZE = 32


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
        W=seeded((HIDDEN_SIZE, INPUT_SIZE), 0.035, 11),
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
        W=seeded((SECOND_HIDDEN_SIZE, HIDDEN_SIZE), 0.045, 1009),
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

    builder.make_updatable(["hidden1", "hidden2", "hidden3", "logits"])
    builder.set_categorical_cross_entropy_loss(name="classification_loss", input="probabilities")
    builder.set_adam_optimizer(AdamParams(lr=0.002, batch=1))
    builder.set_epochs(3)

    spec = builder.spec
    spec.description.input[0].shortDescription = "1120 multimodal prayer-progress, transcript embedding, and 5-second audio features."
    spec.description.output[0].shortDescription = "[stay, advance] probabilities."
    spec.description.trainingInput[0].shortDescription = "Multimodal v2 features."
    spec.description.trainingInput[1].shortDescription = "0 = stay, 1 = advance."

    model = ct.models.MLModel(spec)
    model.author = "Margaretka"
    model.short_description = "Updatable on-device multimodal prayer auto-advance classifier"
    model.user_defined_metadata["modelVersion"] = str(model_version)
    model.user_defined_metadata["featureSchemaVersion"] = "2"
    return model


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="PrayerAutoAdvance.mlmodel")
    parser.add_argument("--model-version", type=int, default=2)
    args = parser.parse_args()

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    build_model(args.model_version).save(str(output))
    print(output.resolve())


if __name__ == "__main__":
    main()
