defmodule Exirc.IRC.MessageParser do
  @moduledoc """
  Parses a framed IRC message into its protocol components.
  """

  @doc """
  Parses one IRC message line.
  """
  def parse(message) do
    [command, parameters] = String.split(message, " ", parts: 2)
    [target, trailing] = String.split(parameters, " ", parts: 2)
    <<":", text::binary>> = trailing

    %{prefix: nil, command: command, params: [target, text]}
  end
end
