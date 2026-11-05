defmodule Exirc.IRC.Connection do
  @moduledoc """
  A connection to an IRC server that sends and receives IRC messages.

  The connection owns the socket and the framing state; protocol flows such as
  registration are built on top of it.
  """
  alias Exirc.IRC.MessageParser
  alias Exirc.IRC.MessageFraming
  alias Exirc.IRC.MessageFormatter
  alias Exirc.IRC.Message

  # The socket and any received bytes that do not yet form a complete IRC
  # message.
  defstruct [:socket, buffer: "", messages: []]

  @doc """
  Opens a connection to `host` and `port`.
  """
  def connect(host, port, _opts \\ []) do
    case :gen_tcp.connect(String.to_charlist(host), port, [:binary, active: false]) do
      {:ok, socket} ->
        {:ok, %__MODULE__{socket: socket}}

      error ->
        error
    end
  end

  def close(%__MODULE__{socket: socket}), do: :gen_tcp.close(socket)

  @doc """
  Sends one IRC message to the server.
  """
  def send_message(%__MODULE__{} = connection, %Message{} = message) do
    line =
      message
      |> MessageFormatter.format()

    case :gen_tcp.send(connection.socket, line) do
      :ok -> {:ok, connection}
      other -> other
    end
  end

  @doc """
  Receives the next IRC message from the server, waiting for more bytes when
  no complete message is available yet.
  """
  def recv_message(connection, timeout \\ :infinity)

  def recv_message(%__MODULE__{messages: []} = connection, timeout) do
    case :gen_tcp.recv(connection.socket, 0, timeout) do
      {:ok, raw_bytes} ->
        {messages, buffer} = MessageFraming.feed(connection.buffer, raw_bytes)
        recv_message(%__MODULE__{connection | messages: messages, buffer: buffer}, timeout)

      error ->
        error
    end
  end

  def recv_message(%__MODULE__{messages: [raw_message | messages]} = connection, _timeout) do
    message = MessageParser.parse(raw_message)
    {:ok, %__MODULE__{connection | messages: messages}, message}
  end
end
