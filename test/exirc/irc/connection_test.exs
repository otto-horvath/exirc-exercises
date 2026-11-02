defmodule Exirc.IRC.ConnectionTest do
  use ExUnit.Case, async: true

  alias Exirc.IRC.Connection
  alias Exirc.IRC.Message
  alias Exirc.Test.FakeIRCServer

  @opts [nick: "remo", username: "remo", realname: "Remo the Chameleon"]
  @welcome ":irc.test 001 remo :Welcome to the Test IRC Network remo"

  # register/3 blocks until the server welcomes the client, so the client runs
  # in a task while the test process plays the server.
  defp start_register(opts \\ @opts) do
    server = FakeIRCServer.listen()
    task = Task.async(fn -> Connection.register("127.0.0.1", server.port, opts) end)

    {FakeIRCServer.accept(server), task}
  end

  defp read_registration(server) do
    assert FakeIRCServer.recv_line(server) == "NICK remo"
    assert FakeIRCServer.recv_line(server) == "USER remo 0 * :Remo the Chameleon"
  end

  test "sends NICK and USER after connecting" do
    {server, task} = start_register()

    read_registration(server)
    FakeIRCServer.send_line(server, @welcome)

    assert {:ok, %Connection{}, _welcome} = Task.await(task)
  end

  test "sends PASS first when a password is given" do
    {server, task} = start_register(Keyword.put(@opts, :password, "local-test-password"))

    assert FakeIRCServer.recv_line(server) == "PASS local-test-password"
    read_registration(server)
    FakeIRCServer.send_line(server, @welcome)

    assert {:ok, %Connection{}, _welcome} = Task.await(task)
  end

  test "returns the parsed welcome reply" do
    {server, task} = start_register()

    read_registration(server)
    FakeIRCServer.send_line(server, @welcome)

    assert {:ok, _connection, welcome} = Task.await(task)

    assert welcome == %Message{
             prefix: "irc.test",
             command: "001",
             params: ["remo", "Welcome to the Test IRC Network remo"]
           }
  end

  test "skips server messages received before the welcome" do
    {server, task} = start_register()

    read_registration(server)
    FakeIRCServer.send_line(server, ":irc.test NOTICE * :*** Looking up your hostname...")
    FakeIRCServer.send_line(server, @welcome)

    assert {:ok, _connection, %Message{command: "001"}} = Task.await(task)
  end

  test "frames several server messages sent in one write" do
    {server, task} = start_register()

    read_registration(server)

    FakeIRCServer.send_raw(
      server,
      ":irc.test NOTICE * :*** Looking up your hostname...\r\n" <> @welcome <> "\r\n"
    )

    assert {:ok, _connection, %Message{command: "001"}} = Task.await(task)
  end

  test "frames a welcome split across writes" do
    {server, task} = start_register()

    read_registration(server)
    FakeIRCServer.send_raw(server, ":irc.test 001 remo :Welcome to the")
    FakeIRCServer.send_raw(server, " Test IRC Network remo\r")
    FakeIRCServer.send_raw(server, "\n")

    assert {:ok, _connection, %Message{command: "001"}} = Task.await(task)
  end

  test "keeps bytes received after the welcome in the connection buffer" do
    {server, task} = start_register()

    read_registration(server)
    FakeIRCServer.send_raw(server, @welcome <> "\r\n:irc.test 002 remo :Your host")

    assert {:ok, %Connection{buffer: ":irc.test 002 remo :Your host"}, _welcome} =
             Task.await(task)
  end
end
