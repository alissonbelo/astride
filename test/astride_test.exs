defmodule AstrideTest do
  use ExUnit.Case
  doctest Astride

  test "greets the world" do
    assert Astride.hello() == :world
  end
end
