defmodule Exirc.IRC.SessionTest do
  use ExUnit.Case, async: true

  alias Exirc.IRC.Message
  alias Exirc.IRC.MessageParser
  alias Exirc.IRC.Session
  alias Exirc.Test.FakeIRCServer

  @registration [nick: "remo", username: "remo", realname: "Remo the Chameleon"]

  test "answers a server PING with the same token and keeps the session alive" do
    server = FakeIRCServer.listen()
    {:ok, session} = Session.start_link("127.0.0.1", server.port, @registration)
    server = FakeIRCServer.accept(server)

    assert FakeIRCServer.recv_line(server) == "NICK remo"
    assert FakeIRCServer.recv_line(server) == "USER remo 0 * :Remo the Chameleon"
    FakeIRCServer.send_line(server, ":irc.test 001 remo :Welcome to the Test IRC Network remo")

    FakeIRCServer.send_line(server, "PING :session-check-42")

    assert server
           |> FakeIRCServer.recv_line()
           |> MessageParser.parse() == %Message{command: "PONG", params: ["session-check-42"]}

    assert Process.alive?(session)
    GenServer.stop(session)
  end

  test "sends parsed non-PING server messages to the observer" do
    server = FakeIRCServer.listen()

    {:ok, session} =
      Session.start_link("127.0.0.1", server.port, @registration, observer: self())

    server = FakeIRCServer.accept(server)

    assert FakeIRCServer.recv_line(server) == "NICK remo"
    assert FakeIRCServer.recv_line(server) == "USER remo 0 * :Remo the Chameleon"
    FakeIRCServer.send_line(server, ":irc.test 001 remo :Welcome to the Test IRC Network remo")

    notice = ":irc.test NOTICE remo :A message from the server"
    FakeIRCServer.send_line(server, notice)

    assert_receive {:irc_message,
                    %Message{
                      prefix: "irc.test",
                      command: "NOTICE",
                      params: ["remo", "A message from the server"]
                    }}

    assert Process.alive?(session)
    GenServer.stop(session)
  end

  test "dispatches each server message only once across TCP deliveries" do
    server = FakeIRCServer.listen()

    {:ok, session} =
      Session.start_link("127.0.0.1", server.port, @registration, observer: self())

    server = FakeIRCServer.accept(server)

    assert FakeIRCServer.recv_line(server) == "NICK remo"
    assert FakeIRCServer.recv_line(server) == "USER remo 0 * :Remo the Chameleon"
    FakeIRCServer.send_line(server, ":irc.test 001 remo :Welcome to the Test IRC Network remo")

    first_notice = %Message{
      prefix: "irc.test",
      command: "NOTICE",
      params: ["remo", "first"]
    }

    second_notice = %Message{
      prefix: "irc.test",
      command: "NOTICE",
      params: ["remo", "second"]
    }

    FakeIRCServer.send_line(server, ":irc.test NOTICE remo :first")
    assert_receive {:irc_message, ^first_notice}

    FakeIRCServer.send_line(server, ":irc.test NOTICE remo :second")
    assert_receive {:irc_message, ^second_notice}
    refute_receive {:irc_message, ^first_notice}, 50

    GenServer.stop(session)
  end
end
