defmodule Exirc.IRC.MessageParser do
  @moduledoc """
  Parses a framed IRC message into its protocol components.
  """

  @doc """
  Parses one IRC message line.
  """
  def parse(message) do
    [command, parameters] = String.split(message, " ", parts: 2)

    %{prefix: nil, command: command, params: parse_parameters(parameters)}
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
