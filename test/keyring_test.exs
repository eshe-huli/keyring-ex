defmodule KeyringTest do
  use ExUnit.Case
  doctest Keyring

  test "greets the world" do
    assert Keyring.hello() == :world
  end
end
