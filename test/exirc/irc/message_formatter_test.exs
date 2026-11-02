defmodule Exirc.IRC.MessageFormatterTest do
  use ExUnit.Case, async: true

  alias Exirc.IRC.Message
  alias Exirc.IRC.MessageFormatter
  alias Exirc.IRC.MessageParser

  test "formats a command with no parameters" do
    assert MessageFormatter.format(%Message{command: "QUIT"}) == "QUIT\r\n"
  end

  test "formats middle parameters separated by spaces" do
    assert MessageFormatter.format(%Message{command: "NICK", params: ["remo"]}) ==
             "NICK remo\r\n"
  end

  test "marks a final parameter containing spaces as trailing" do
    assert MessageFormatter.format(%Message{
             command: "USER",
             params: ["remo", "0", "*", "Remo the Chameleon"]
           }) == "USER remo 0 * :Remo the Chameleon\r\n"
  end

  test "marks a sole parameter containing spaces as trailing" do
    assert MessageFormatter.format(%Message{command: "QUIT", params: ["Gone home"]}) ==
             "QUIT :Gone home\r\n"
  end

  test "marks an empty final parameter as trailing" do
    assert MessageFormatter.format(%Message{command: "PRIVMSG", params: ["#brasil", ""]}) ==
             "PRIVMSG #brasil :\r\n"
  end

  test "marks a final parameter starting with a colon as trailing" do
    assert MessageFormatter.format(%Message{command: "PRIVMSG", params: ["#brasil", ":)"]}) ==
             "PRIVMSG #brasil ::)\r\n"
  end

  test "formatted messages parse back to the same message" do
    message = %Message{command: "PRIVMSG", params: ["#brasil", "Olá, pessoal!"]}

    assert message
           |> MessageFormatter.format()
           |> String.trim_trailing("\r\n")
           |> MessageParser.parse() == message
  end
end
