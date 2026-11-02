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
    {:ok, socket} = :gen_tcp.connect(String.to_charlist(host), port, [:binary, active: false])

    {:ok, %__MODULE__{socket: socket}}
  end

  @doc """
  Sends one IRC message to the server.
  """
  def send_message(%__MODULE__{} = connection, %Message{} = message) do
    line =
      message
      |> MessageFormatter.format()

    :gen_tcp.send(connection.socket, line)

    {:ok, connection}
  end

  @doc """
  Receives the next IRC message from the server, waiting for more bytes when
  no complete message is available yet.
  """
  def recv_message(%__MODULE__{messages: []} = connection) do
    {:ok, raw_bytes} = :gen_tcp.recv(connection.socket, 0)
    {messages, buffer} = MessageFraming.feed(connection.buffer, raw_bytes)
    recv_message(%__MODULE__{connection | messages: messages, buffer: buffer})
  end

  def recv_message(%__MODULE__{messages: [raw_message | messages]} = connection) do
    message = MessageParser.parse(raw_message)
    {:ok, %__MODULE__{connection | messages: messages}, message}
  end
end
