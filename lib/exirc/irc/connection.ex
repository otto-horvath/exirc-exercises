defmodule Exirc.IRC.Connection do
  @moduledoc """
  A connection to an IRC server that sends and receives IRC messages.

  The connection owns the socket and the framing state; protocol flows such as
  registration are built on top of it.
  """

  # The socket and any received bytes that do not yet form a complete IRC
  # message.
  defstruct [:socket, buffer: ""]

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
  def send_message(_connection, _message) do
    raise "not implemented"
  end

  @doc """
  Receives the next IRC message from the server, waiting for more bytes when
  no complete message is available yet.
  """
  def recv_message(_connection) do
    raise "not implemented"
  end
end
