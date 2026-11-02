defmodule Exirc.IRC.RegistrationFlowTest do
  use ExUnit.Case, async: true

  alias Exirc.IRC.Connection
  alias Exirc.IRC.Message
  alias Exirc.IRC.Registration
  alias Exirc.Test.FakeIRCServer

  @registration [nick: "remo", username: "remo", realname: "Remo the Chameleon"]
  @welcome ":irc.test 001 remo :Welcome to the Test IRC Network remo"

  # register/2 blocks until the server welcomes the client, so the client runs
  # in a task while the test process plays the server. The task owns the
  # socket, so anything that uses the connection afterwards runs in `client`.
  defp start_client(client) do
    server = FakeIRCServer.listen()

    task =
      Task.async(fn ->
        {:ok, connection} = Connection.connect("127.0.0.1", server.port)
        client.(connection)
      end)

    {FakeIRCServer.accept(server), task}
  end

  defp register(registration \\ @registration) do
    start_client(&Registration.register(&1, registration))
  end

  defp read_nick_and_user(server) do
    assert FakeIRCServer.recv_line(server) == "NICK remo"
    assert FakeIRCServer.recv_line(server) == "USER remo 0 * :Remo the Chameleon"
  end

  test "sends NICK and USER and returns the welcome reply" do
    {server, task} = register()

    read_nick_and_user(server)
    FakeIRCServer.send_line(server, @welcome)

    assert {:ok, %Connection{}, welcome} = Task.await(task)

    assert welcome == %Message{
             prefix: "irc.test",
             command: "001",
             params: ["remo", "Welcome to the Test IRC Network remo"]
           }
  end

  test "sends PASS first when a password is given" do
    {server, task} = register(Keyword.put(@registration, :password, "local-test-password"))

    assert FakeIRCServer.recv_line(server) == "PASS local-test-password"
    read_nick_and_user(server)
    FakeIRCServer.send_line(server, @welcome)

    assert {:ok, %Connection{}, %Message{command: "001"}} = Task.await(task)
  end

  test "skips server messages received before the welcome" do
    {server, task} = register()

    read_nick_and_user(server)
    FakeIRCServer.send_line(server, ":irc.test NOTICE * :*** Looking up your hostname...")
    FakeIRCServer.send_line(server, @welcome)

    assert {:ok, %Connection{}, %Message{command: "001"}} = Task.await(task)
  end

  test "leaves messages received after the welcome on the connection" do
    {server, task} =
      start_client(fn connection ->
        {:ok, connection, _welcome} = Registration.register(connection, @registration)
        Connection.recv_message(connection)
      end)

    read_nick_and_user(server)

    FakeIRCServer.send_raw(
      server,
      @welcome <> "\r\n:irc.test 002 remo :Your host is irc.test\r\n"
    )

    assert {:ok, %Connection{}, %Message{command: "002"}} = Task.await(task)
  end
end
