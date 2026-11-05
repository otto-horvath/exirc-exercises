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

  describe "invalid input" do
    test "raises when a non-final parameter contains a space" do
      assert_raise ArgumentError, fn ->
        MessageFormatter.format(%Message{command: "PRIVMSG", params: ["a b", "c", "d"]})
      end
    end

    test "raises when a non-final parameter starts with a colon" do
      assert_raise ArgumentError, fn ->
        MessageFormatter.format(%Message{command: "PRIVMSG", params: [":middle", "last"]})
      end
    end

    test "raises when a non-final parameter is empty" do
      assert_raise ArgumentError, fn ->
        MessageFormatter.format(%Message{command: "PRIVMSG", params: ["", "last"]})
      end
    end

    test "raises when a parameter contains CR" do
      assert_raise ArgumentError, fn ->
        MessageFormatter.format(%Message{command: "PRIVMSG", params: ["#brasil", "hello\rworld"]})
      end
    end

    test "raises when a parameter contains LF" do
      assert_raise ArgumentError, fn ->
        MessageFormatter.format(%Message{command: "PRIVMSG", params: ["#brasil", "hello\nworld"]})
      end
    end

    test "raises when a parameter contains NUL" do
      assert_raise ArgumentError, fn ->
        MessageFormatter.format(%Message{command: "PRIVMSG", params: ["#brasil", "hello\0world"]})
      end
    end

    test "raises when a parameter is not a binary" do
      assert_raise ArgumentError, fn ->
        MessageFormatter.format(%Message{command: "PRIVMSG", params: ["#brasil", :not_a_string]})
      end
    end
  end
end
