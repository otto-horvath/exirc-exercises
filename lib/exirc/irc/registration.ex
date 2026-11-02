defmodule Exirc.IRC.Registration do
  @moduledoc """
  Builds the messages a client sends to register an IRC connection.
  """

  @doc """
  Returns the registration messages in the order they must be sent.
  """
  def messages(_registration) do
    raise "not implemented"
  end
end
