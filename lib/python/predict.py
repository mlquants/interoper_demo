import os, sys

from struct import unpack, pack
import msgpack

from feature_transformation import FeatureTransformerInference
from prediction_client import RandomForestClient, RandomClient

UUID4_SIZE = 16


# setup of FD 3 for input (instead of stdin)
# FD 4 for output (instead of stdout)
def setup_io():
    return os.fdopen(3, "rb"), os.fdopen(4, "wb")


def read_message(input_frame):
    # reading the first 4 bytes with the length of the data
    # the other 32 bytes are the UUID string,
    # the rest is the image

    header = input_frame.read(4)
    if len(header) != 4:
        return None  # EOF

    (total_msg_size,) = unpack("!I", header)

    frame_id = input_frame.read(UUID4_SIZE)

    # read frame data
    frame_data = input_frame.read(total_msg_size - UUID4_SIZE)

    return {"id": frame_id, "data": msgpack.loads(frame_data)}


def write_result(output, frame_id, data):
    result = msgpack.dumps(data)

    header = pack("!I", len(result) + UUID4_SIZE)
    output.write(header)
    output.write(frame_id)
    output.write(result)
    output.flush()


def init(args) -> dict:
    # we can load model based on values passed in init_arguments and store it as a context
    fti = FeatureTransformerInference(fname=args[0])
    client = RandomForestClient(fname=args[1])
    # client = RandomClient()
    return {"model": client, "feature_transformer": fti}


def do_predict(data: dict, context: dict) -> dict:
    feature_vector = context["feature_transformer"].transform_observation_to_feature_vector(data)
    prediction = context["model"].predict_one(feature_vector)
    return {"success": True, "prediction": prediction}


def predict(msg: dict, context: dict) -> dict:
    # we can use initialized model from context
    data = msg.get("data", {})
    print(f"Python side print: {data}")

    if data.get("raise"):
        raise RuntimeError("foo-bar")
    elif data.get("error"):
        return {"success": False, "based_on_input": msg, "context": context}
    else:
        return do_predict(data, context)


def run(args):
    input_f, output_f = setup_io()

    context = init(args[1].split(" "))

    while True:
        msg = read_message(input_f)
        if msg is None:
            break

        result = predict(msg, context)
        # send result back to elixir:
        write_result(output_f, msg["id"], result)


if __name__ == "__main__":
    run(sys.argv)
