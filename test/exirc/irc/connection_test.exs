defmodule Exirc.IRC.ConnectionTest do
  use ExUnit.Case, async: true

  alias Exirc.IRC.Connection
  alias Exirc.IRC.Message
  alias Exirc.Test.FakeIRCServer

  # connect/3 returns once the OS has queued the connection, so the test
  # process can play both the client and the fake server.
  setup do
    server = FakeIRCServer.listen()
    {:ok, connection} = Connection.connect("127.0.0.1", server.port)

    %{server: FakeIRCServer.accept(server), connection: connection}
  end

  test "connects to the server", %{connection: connection} do
    assert %Connection{} = connection
  end

  test "sends a message as a CRLF-terminated line", %{server: server, connection: connection} do
    assert {:ok, %Connection{}} =
             Connection.send_message(connection, %Message{command: "NICK", params: ["remo"]})

    assert FakeIRCServer.recv_line(server) == "NICK remo"
  end

  test "receives a parsed message", %{server: server, connection: connection} do
    FakeIRCServer.send_line(server, ":irc.test 001 remo :Welcome to the Test IRC Network remo")

    assert {:ok, %Connection{}, message} = Connection.recv_message(connection)

    assert message == %Message{
             prefix: "irc.test",
             command: "001",
             params: ["remo", "Welcome to the Test IRC Network remo"]
           }
  end

  test "receives several messages sent in one write, in order", %{
    server: server,
    connection: connection
  } do
    FakeIRCServer.send_raw(server, ":irc.test 001 remo :Welcome\r\n:irc.test 002 remo :Host\r\n")

    assert {:ok, connection, %Message{command: "001"}} = Connection.recv_message(connection)
    assert {:ok, _connection, %Message{command: "002"}} = Connection.recv_message(connection)
  end

  test "receives a message split across writes", %{server: server, connection: connection} do
    FakeIRCServer.send_raw(server, ":irc.test 001 remo :Welcome to the")
    FakeIRCServer.send_raw(server, " Test IRC Network remo\r")
    FakeIRCServer.send_raw(server, "\n")

    assert {:ok, _connection, %Message{command: "001", params: ["remo", welcome]}} =
             Connection.recv_message(connection)

    assert welcome == "Welcome to the Test IRC Network remo"
  end

  test "keeps a partial message until the rest arrives", %{
    server: server,
    connection: connection
  } do
    FakeIRCServer.send_raw(server, ":irc.test 001 remo :Welcome\r\n:irc.test 002 remo :Your")

    assert {:ok, connection, %Message{command: "001"}} = Connection.recv_message(connection)

    FakeIRCServer.send_raw(server, " host is irc.test\r\n")

    assert {:ok, _connection, %Message{command: "002", params: ["remo", "Your host is irc.test"]}} =
             Connection.recv_message(connection)
  end
end
