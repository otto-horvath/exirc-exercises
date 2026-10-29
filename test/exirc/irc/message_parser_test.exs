defmodule Exirc.IRC.MessageParserTest do
  use ExUnit.Case, async: true

  alias Exirc.IRC.Message
  alias Exirc.IRC.MessageParser

  test "parses a command with a middle parameter and a trailing message" do
    assert MessageParser.parse("PRIVMSG #brasil :Olá, pessoal!") ==
             %Message{prefix: nil, command: "PRIVMSG", params: ["#brasil", "Olá, pessoal!"]}
  end

  test "parses multiple middle parameters before a trailing parameter" do
    assert MessageParser.parse("CAP LS * :multi-prefix sasl") ==
             %Message{prefix: nil, command: "CAP", params: ["LS", "*", "multi-prefix sasl"]}
  end

  test "parses a source prefix before the command" do
    assert MessageParser.parse(":friend1!user@host PRIVMSG #brasil :Olá, pessoal!") ==
             %Message{
               prefix: "friend1!user@host",
               command: "PRIVMSG",
               params: ["#brasil", "Olá, pessoal!"]
             }
  end

  test "parses a key-value tag before the command" do
    assert MessageParser.parse("@time=2026-10-29T12:00:00Z PING :server") ==
             %Message{
               tags: %{"time" => "2026-10-29T12:00:00Z"},
               prefix: nil,
               command: "PING",
               params: ["server"]
             }
  end
end
