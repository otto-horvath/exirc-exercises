defmodule Exirc.IRC.MessageFraming do
  @crlf "\r\n"

  @moduledoc """
  Frames IRC messages from chunks of a TCP byte stream.
  """

  @doc """
  Adds a chunk to the existing buffer and returns complete messages and the
  remaining incomplete buffer.
  """
  def feed(buffer, chunk) do
    {messages, rest} = extract_messages(buffer <> chunk, [])

    {Enum.reverse(messages), rest}
  end

  defp extract_messages(data, messages) do
    case :binary.match(data, @crlf) do
      {position, delimiter_size} ->
        rest_position = position + delimiter_size
        rest_size = byte_size(data) - rest_position
        rest = binary_part(data, rest_position, rest_size)

        if position == 0 do
          extract_messages(rest, messages)
        else
          message = binary_part(data, 0, position)
          extract_messages(rest, [message | messages])
        end

      :nomatch ->
        {messages, data}
    end
  end
end
