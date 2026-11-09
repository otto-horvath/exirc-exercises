defmodule Exirc.IRC.Session do
  use GenServer

  alias Exirc.IRC.MessageParser
  alias Exirc.IRC.MessageFraming
  alias Exirc.IRC.Message
  alias Exirc.IRC.Registration
  alias Exirc.IRC.Connection

  @impl true
  def init(%{host: host, port: port, params: params, observer: observer}) do
    {:ok, connection} = Connection.connect(host, port)

    {:ok, %{connection: connection, observer: observer}, {:continue, params}}
  end

  @impl true
  def handle_continue(params, %{connection: connection, observer: observer} = state) do
    {:ok, connection, _message} = Registration.register(connection, params)

    %Connection{messages: messages} = connection

    messages
    |> Enum.map(&MessageParser.parse/1)
    |> Enum.each(fn message -> handle_irc_message(message, connection, observer) end)

    :inet.setopts(connection.socket, active: true)

    {:noreply, %{state | connection: %Connection{connection | messages: []}}}
  end

  @impl true
  def handle_info({:tcp, _socket, bytes}, %{connection: connection, observer: observer}) do
    %Connection{buffer: buffer, messages: old_messages} = connection
    {messages, buffer} = MessageFraming.feed(buffer, bytes)

    updated_messages = old_messages ++ messages

    irc_messages =
      updated_messages
      |> Enum.map(&MessageParser.parse/1)

    irc_messages
    |> Enum.filter(fn %Message{command: command} -> command == "PING" end)
    |> Enum.each(fn message -> handle_irc_message(message, connection, observer) end)

    irc_messages
    |> Enum.filter(fn %Message{command: command} -> command != "PING" end)
    |> Enum.each(fn message -> handle_irc_message(message, connection, observer) end)

    updated_connection = %Connection{connection | messages: [], buffer: buffer}

    {:noreply, %{connection: updated_connection, observer: observer}}
  end

  defp handle_irc_message(%Message{command: "PING", params: params}, connection, _observer) do
    Connection.send_message(connection, %Message{command: "PONG", params: params})
  end

  defp handle_irc_message(%Message{command: "NOTICE"} = _message, _connection, observer)
       when is_nil(observer), do: :noop

  defp handle_irc_message(%Message{command: "NOTICE"} = message, _connection, observer) do
    send(observer, {:irc_message, message})
  end

  def start_link(host, port, params, opts \\ [])

  def start_link(host, port, params, opts) do
    observer = Keyword.get(opts, :observer)

    GenServer.start_link(__MODULE__, %{host: host, port: port, params: params, observer: observer})
  end
end
