defmodule Exirc.IRC.RegistrationFlowTest do
  use ExUnit.Case, async: true

  alias Exirc.IRC.Connection
  alias Exirc.IRC.Message
  alias Exirc.IRC.Registration
  alias Exirc.Test.FakeIRCServer

  @registration [nick: "remo", username: "remo", realname: "Remo the Chameleon"]
  @welcome ":irc.test 001 remo :Welcome to the Test IRC Network remo"

  # register/3 blocks until the server welcomes the client, so the client runs
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

  describe "when registration fails" do
    # Keeps the client process (and so its socket) alive after register/3
    # returns, so the test can check that register/3 itself closed the socket.
    defp register_and_report(opts) do
      test_process = self()

      start_client(fn connection ->
        send(test_process, {:registered, Registration.register(connection, @registration, opts)})

        receive do
          :stop -> :ok
        end
      end)
    end

    defp stop_client(task) do
      send(task.pid, :stop)
      Task.await(task)
    end

    test "returns an error when the nickname is in use and closes the connection" do
      {server, task} = register_and_report([])

      read_nick_and_user(server)
      FakeIRCServer.send_line(server, ":irc.test 433 * remo :Nickname is already in use")

      assert_receive {:registered, {:error, {:nickname_in_use, "remo"}}}
      FakeIRCServer.assert_closed(server)
      stop_client(task)
    end

    test "returns an error when the password is rejected" do
      {server, task} = register_and_report([])

      read_nick_and_user(server)
      FakeIRCServer.send_line(server, ":irc.test 464 remo :Password incorrect")

      assert_receive {:registered, {:error, :password_mismatch}}
      FakeIRCServer.assert_closed(server)
      stop_client(task)
    end

    test "returns the reason when the server sends ERROR" do
      {server, task} = register_and_report([])

      read_nick_and_user(server)
      FakeIRCServer.send_line(server, "ERROR :Closing link: (remo@127.0.0.1) [Access denied]")

      assert_receive {:registered,
                      {:error, {:server_error, "Closing link: (remo@127.0.0.1) [Access denied]"}}}

      FakeIRCServer.assert_closed(server)
      stop_client(task)
    end

    test "returns an error when the server closes the connection before the welcome" do
      {server, task} = register_and_report([])

      read_nick_and_user(server)
      FakeIRCServer.close(server)

      assert_receive {:registered, {:error, :closed}}
      stop_client(task)
    end

    test "returns an error when no welcome arrives in time" do
      {server, task} = register_and_report(timeout: 50)

      read_nick_and_user(server)

      assert_receive {:registered, {:error, :timeout}}
      FakeIRCServer.assert_closed(server)
      stop_client(task)
    end

    test "times out the whole registration, not each read" do
      {server, task} = register_and_report(timeout: 100)

      read_nick_and_user(server)

      # A notice every 30 ms for ~450 ms means no single read waits 100 ms.
      # Only a deadline for the whole registration ends it before the notices
      # stop. Sends may fail once the client has given up and closed.
      for _notice <- 1..15 do
        :gen_tcp.send(server.socket, ":irc.test NOTICE * :*** Still checking...\r\n")
        Process.sleep(30)
      end

      assert_received {:registered, {:error, :timeout}}
      stop_client(task)
    end
  end
end
