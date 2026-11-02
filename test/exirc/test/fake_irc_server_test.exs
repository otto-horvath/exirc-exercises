defmodule Exirc.Test.FakeIRCServerTest do
  use ExUnit.Case, async: true

  alias Exirc.Test.FakeIRCServer

  # These tests use a bare :gen_tcp client so the fake server is verified
  # independently of the client code it will later test.
  setup do
    server = FakeIRCServer.listen()

    {:ok, client} =
      :gen_tcp.connect({127, 0, 0, 1}, server.port, [:binary, active: false])

    %{server: FakeIRCServer.accept(server), client: client}
  end

  test "listens on an OS-assigned local port", %{server: server} do
    assert server.port > 0
  end

  test "reads client lines without their CRLF", %{server: server, client: client} do
    :ok = :gen_tcp.send(client, "NICK remo\r\nUSER remo 0 * :Remo\r\n")

    assert FakeIRCServer.recv_line(server) == "NICK remo"
    assert FakeIRCServer.recv_line(server) == "USER remo 0 * :Remo"
  end

  test "fails when the client ends a line without CR", %{server: server, client: client} do
    :ok = :gen_tcp.send(client, "NICK remo\n")

    assert_raise ExUnit.AssertionError, ~r/CRLF-terminated/, fn ->
      FakeIRCServer.recv_line(server)
    end
  end

  test "fails when the client sends no line in time", %{server: server} do
    assert_raise ExUnit.AssertionError, ~r/timeout/, fn ->
      FakeIRCServer.recv_line(server, 10)
    end
  end

  test "sends lines terminated by CRLF", %{server: server, client: client} do
    FakeIRCServer.send_line(server, ":irc.test 001 remo :Welcome")

    assert :gen_tcp.recv(client, 0, 1_000) == {:ok, ":irc.test 001 remo :Welcome\r\n"}
  end

  test "sends raw bytes exactly as given", %{server: server, client: client} do
    FakeIRCServer.send_raw(server, ":irc.test 001 re")

    assert :gen_tcp.recv(client, 0, 1_000) == {:ok, ":irc.test 001 re"}
  end

  test "closes the client connection", %{server: server, client: client} do
    FakeIRCServer.close(server)

    assert :gen_tcp.recv(client, 0, 1_000) == {:error, :closed}
  end
end
