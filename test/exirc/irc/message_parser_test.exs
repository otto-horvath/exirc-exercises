defmodule Exirc.IRC.MessageParserTest do
  use ExUnit.Case, async: true

  alias Exirc.IRC.MessageParser

  test "parses a command with a middle parameter and a trailing message" do
    assert MessageParser.parse("PRIVMSG #brasil :Olá, pessoal!") == %{
             prefix: nil,
             command: "PRIVMSG",
             params: ["#brasil", "Olá, pessoal!"]
           }
  end

  test "parses multiple middle parameters before a trailing parameter" do
    assert MessageParser.parse("CAP LS * :multi-prefix sasl") == %{
             prefix: nil,
             command: "CAP",
             params: ["LS", "*", "multi-prefix sasl"]
           }
  end
end
