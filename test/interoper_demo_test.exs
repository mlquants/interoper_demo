defmodule InteroperDemoTest do
  use ExUnit.Case
  doctest InteroperDemo

  test "greets the world" do
    assert InteroperDemo.hello() == :world
  end
end
