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
end
