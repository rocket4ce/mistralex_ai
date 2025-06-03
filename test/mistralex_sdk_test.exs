defmodule MistralexSdkTest do
  use ExUnit.Case
  doctest MistralexSdk

  test "greets the world" do
    assert MistralexSdk.hello() == :world
  end
end
