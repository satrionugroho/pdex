defmodule PdexTest do
  use ExUnit.Case
  doctest Pdex

  test "greets the world" do
    assert Pdex.hello() == :world
  end
end
