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

  test "returns an error when sending on a closed connection", %{connection: connection} do
    :ok = Connection.close(connection)

    # apply/3 keeps the call dynamic: send_message/2 currently always returns
    # {:ok, connection}, so a direct comparison warns about disjoint types
    # before the implementation is fixed.
    result =
      apply(Connection, :send_message, [
        connection,
        %Message{command: "NICK", params: ["remo"]}
      ])

    assert result == {:error, :closed}
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

  test "returns an error when the server closes the connection", %{
    server: server,
    connection: connection
  } do
    FakeIRCServer.close(server)

    assert Connection.recv_message(connection) == {:error, :closed}
  end

  test "returns an error when no complete message arrives in time", %{
    server: server,
    connection: connection
  } do
    FakeIRCServer.send_raw(server, ":irc.test 001 remo :Welc")

    assert Connection.recv_message(connection, 50) == {:error, :timeout}
  end

  test "returns a waiting message without waiting for the timeout", %{
    server: server,
    connection: connection
  } do
    FakeIRCServer.send_raw(server, ":irc.test 001 remo :Welcome\r\n:irc.test 002 remo :Host\r\n")

    assert {:ok, connection, %Message{command: "001"}} = Connection.recv_message(connection, 50)
    assert {:ok, _connection, %Message{command: "002"}} = Connection.recv_message(connection, 0)
  end
end

defmodule Exirc.IRC.ConnectionConnectTest do
  use ExUnit.Case, async: true

  alias Exirc.IRC.Connection
  alias Exirc.Test.FakeIRCServer

  test "returns an error when nothing is listening" do
    server = FakeIRCServer.listen()
    :ok = :gen_tcp.close(server.listen_socket)

    assert Connection.connect("127.0.0.1", server.port) == {:error, :econnrefused}
  end
end
