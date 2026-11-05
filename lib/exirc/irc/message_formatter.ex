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

  defp join_params(params) do
    {middle, [last]} = Enum.split(params, -1)

    Enum.each(middle, &validate_middle!/1)
    validate_text!(last)

    middle ++ [format_last(last)]
  end

  defp validate_middle!(param) do
    validate_text!(param)

    if trailing?(param) do
      raise ArgumentError,
            "non-final parameter must be a middle parameter, got: #{inspect(param)}"
    end
  end

  defp validate_text!(param) when is_binary(param) do
    if String.contains?(param, ["\r", "\n", "\0"]) do
      raise ArgumentError,
            "parameter cannot contain CR, LF, or NUL, got: #{inspect(param)}"
    end

    param
  end

  defp validate_text!(param) do
    raise ArgumentError, "parameter must be a string, got: #{inspect(param)}"
  end

  defp format_last(param) do
    if trailing?(param), do: ":" <> param, else: param
  end

  # A parameter must be sent as the trailing parameter when it could not be
  # written as a middle parameter: it is empty, starts with ":", or contains a
  # space.
  defp trailing?(""), do: true
  defp trailing?(":" <> _rest), do: true
  defp trailing?(parameter), do: String.contains?(parameter, " ")
end
