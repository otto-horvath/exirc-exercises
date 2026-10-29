defmodule Exirc.IRC.MessageFraming do
  @moduledoc """
  Frames IRC messages from chunks of a TCP byte stream.
  """

  @doc """
  Adds a chunk to the existing buffer and returns complete messages and the
  remaining incomplete buffer.
  """
  def feed(_buffer, _chunk) do
    raise "not implemented"
  end
end
