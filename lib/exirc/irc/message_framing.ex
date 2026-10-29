defmodule Exirc.IRC.MessageFraming do
  @moduledoc """
  Frames IRC messages from chunks of a TCP byte stream.
  """

  @doc """
  Adds a chunk to the existing buffer and returns complete messages and the
  remaining incomplete buffer.
  """
  def feed(buffer, chunk) do
    {commands, [rest]} =
      (buffer <> chunk)
      |> :binary.split("\r\n", [:global])
      |> Enum.split(-1)

    {commands, rest}
  end
end
