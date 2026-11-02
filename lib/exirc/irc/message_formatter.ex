defmodule Exirc.IRC.MessageFormatter do
  @moduledoc """
  Formats an IRC message struct as a CRLF-terminated wire line.
  """

  alias Exirc.IRC.Message

  @doc """
  Formats one IRC message for sending to a server.
  """
  def format(%Message{command: command, params: params}) do
    prepared_params = join_params(params)
    line = Enum.join([command | prepared_params], " ")
    line <> "\r\n"
  end

  defp join_params([]), do: []

  defp join_params([param]) do
    if trailing?(param) do
      [":#{param}"]
    else
      [param]
    end
  end

  defp join_params([middle | tail]) do
    if trailing?(middle) do
      [Enum.join([":#{middle}", tail], " ")]
    else
      [middle | join_params(tail)]
    end
  end

  # A parameter must be sent as the trailing parameter when it could not be
  # written as a middle parameter: it is empty, starts with ":", or contains a
  # space.
  defp trailing?(""), do: true
  defp trailing?(":" <> _rest), do: true
  defp trailing?(parameter), do: String.contains?(parameter, " ")
end
