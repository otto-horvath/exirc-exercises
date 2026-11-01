defmodule Exirc.IRC.MessageFormatter do
  @moduledoc """
  Formats an IRC message struct as a CRLF-terminated wire line.
  """

  @doc """
  Formats one IRC message for sending to a server.
  """
  def format(_message) do
    raise "not implemented"
  end
end
