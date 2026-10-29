defmodule Exirc.IRC.MessageParser do
  alias Exirc.IRC.Message

  @moduledoc """
  Parses a framed IRC message into its protocol components.
  """

  @doc """
  Parses one IRC message line.
  """
  def parse(message) do
    {tags, message} = parse_tags(message)
    {prefix, message} = parse_prefix(message)

    {command, parameters} =
      case String.split(message, " ", parts: 2) do
        [command, parameters] -> {command, parameters}
        [command] -> {command, ""}
      end

    %Message{
      tags: tags,
      prefix: prefix,
      command: command,
      params: parse_parameters(parameters)
    }
  end

  defp parse_tags(<<"@", message::binary>>) do
    [tag_section, rest] = String.split(message, " ", parts: 2)

    tags =
      tag_section
      |> String.split(";")
      |> Map.new(fn tag ->
        case String.split(tag, "=", parts: 2) do
          [key, value] -> {key, unescape_tag_value(value)}
          [key] -> {key, ""}
        end
      end)

    {tags, rest}
  end

  defp parse_tags(message), do: {%{}, message}

  defp parse_prefix(<<":", message::binary>>) do
    [prefix, rest] = String.split(message, " ", parts: 2)
    {prefix, rest}
  end

  defp parse_prefix(message), do: {nil, message}

  defp unescape_tag_value(value) do
    value
    |> unescape_tag_value([])
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  defp unescape_tag_value(<<>>, decoded), do: decoded

  defp unescape_tag_value(<<"\\:", rest::binary>>, decoded),
    do: unescape_tag_value(rest, [";" | decoded])

  defp unescape_tag_value(<<"\\s", rest::binary>>, decoded),
    do: unescape_tag_value(rest, [" " | decoded])

  defp unescape_tag_value(<<"\\\\", rest::binary>>, decoded),
    do: unescape_tag_value(rest, ["\\" | decoded])

  defp unescape_tag_value(<<"\\r", rest::binary>>, decoded),
    do: unescape_tag_value(rest, ["\r" | decoded])

  defp unescape_tag_value(<<"\\n", rest::binary>>, decoded),
    do: unescape_tag_value(rest, ["\n" | decoded])

  defp unescape_tag_value(<<"\\", rest::binary>>, decoded), do: unescape_tag_value(rest, decoded)

  defp unescape_tag_value(<<byte, rest::binary>>, decoded) do
    unescape_tag_value(rest, [<<byte>> | decoded])
  end

  defp parse_parameters(<<>>), do: []
  defp parse_parameters(<<" ", rest::binary>>), do: parse_parameters(rest)
  defp parse_parameters(<<":", trailing::binary>>), do: [trailing]

  defp parse_parameters(parameters) do
    case String.split(parameters, " ", parts: 2) do
      [parameter, rest] -> [parameter | parse_parameters(rest)]
      [parameter] -> [parameter]
    end
  end
end
