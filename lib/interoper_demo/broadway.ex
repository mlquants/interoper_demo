defmodule InteroperDemo.Broadway do
  @moduledoc """
  A Broadway pipeline.
  """
  use Broadway

  alias Broadway.Message
  alias InteroperDemo.Queue

  require Logger

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {Queue, 0},
        transformer: {__MODULE__, :transform, []}
      ],
      processors: [default: [concurrency: 3]],
      batchers: [default: [concurrency: 1, batch_size: 5, batch_timeout: :timer.seconds(5)]]
    )
  end

  @impl true
  def handle_message(_, %Message{data: _data} = message, _), do: message

  @impl true
  def handle_batch(:default, messages, _batch_info, _context) do
    # do some batch processing here
    Logger.info("processing batch of #{length(messages)}")
    messages
  end

  def transform(event, _opts) do
    %Message{data: event, acknowledger: {__MODULE__, :ack_id, :ack_data}}
  end

  # Write acknowledge code here:
  def ack(:ack_id, _successful, _failed), do: :noop
end
