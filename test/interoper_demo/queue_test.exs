defmodule InteroperDemo.QueueTest do
  use ExUnit.Case
  doctest InteroperDemo.Queue
  alias InteroperDemo.Queue

  test "pop" do
    queue = Qex.new([1, 2, 3, 4, 5])

    assert {[1, 2, 3], tail_queue} = Queue.pop(queue, 3)
    assert tail_queue == Qex.new([4, 5])
  end
end
