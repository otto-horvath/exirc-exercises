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
    [command, parameters] = String.split(message, " ", parts: 2)

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
          [key, value] -> {key, value}
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
