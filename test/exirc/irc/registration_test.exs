defmodule Exirc.IRC.RegistrationTest do
  use ExUnit.Case, async: true

  alias Exirc.IRC.Message
  alias Exirc.IRC.MessageFormatter
  alias Exirc.IRC.Registration

  @registration %{nick: "remo", username: "remo", realname: "Remo the Chameleon"}

  test "sends NICK then USER when there is no password" do
    assert Registration.messages(@registration) == [
             %Message{command: "NICK", params: ["remo"]},
             %Message{command: "USER", params: ["remo", "0", "*", "Remo the Chameleon"]}
           ]
  end

  test "treats a nil password as no password" do
    assert Registration.messages(Map.put(@registration, :password, nil)) ==
             Registration.messages(@registration)
  end

  test "sends PASS before NICK and USER when a password is set" do
    assert [
             %Message{command: "PASS", params: ["local-test-password"]},
             %Message{command: "NICK"},
             %Message{command: "USER"}
           ] = Registration.messages(Map.put(@registration, :password, "local-test-password"))
  end

  test "registration messages format as wire lines" do
    assert @registration
           |> Registration.messages()
           |> Enum.map(&MessageFormatter.format/1) == [
             "NICK remo\r\n",
             "USER remo 0 * :Remo the Chameleon\r\n"
           ]
  end
end
