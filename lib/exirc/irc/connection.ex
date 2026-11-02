defmodule Exirc.IRC.Connection do
  @moduledoc """
  Opens a connection to an IRC server and registers the client.
  """

  # A registered connection: the socket and any received bytes that do not
  # yet form a complete IRC message.
  defstruct [:socket, buffer: ""]

  @doc """
  Connects to `host` and `port`, sends the registration messages, and waits
  for the server's welcome reply (`001`).
  """
  def register(_host, _port, _opts) do
    raise "not implemented"
  end
end
