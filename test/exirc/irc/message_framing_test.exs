defmodule Exirc.IRC.MessageFramingTest do
  use ExUnit.Case, async: true

  alias Exirc.IRC.MessageFraming

  test "emits a complete CRLF-terminated message and clears the buffer" do
    assert MessageFraming.feed("", "PING :server\r\n") == {["PING :server"], ""}
  end

  test "retains an incomplete message until its CRLF arrives" do
    assert MessageFraming.feed("PING :serv", "er") == {[], "PING :server"}
    assert MessageFraming.feed("PING :server", "\r\n") == {["PING :server"], ""}
  end

  test "emits multiple messages and retains a trailing partial message" do
    chunk = "PING :one\r\nPONG :two\r\nPRIVMSG #elixir :hel"

    assert MessageFraming.feed("", chunk) ==
             {["PING :one", "PONG :two"], "PRIVMSG #elixir :hel"}
  end

  test "handles the CR and LF split across chunks" do
    assert MessageFraming.feed("", "PING :server\r") == {[], "PING :server\r"}
    assert MessageFraming.feed("PING :server\r", "\n") == {["PING :server"], ""}
  end
end
