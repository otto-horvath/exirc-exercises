defmodule Exirc.IRC.Message do
  @moduledoc """
  Structured representation of a parsed IRC message.
  """

  defstruct tags: %{}, prefix: nil, command: nil, params: []
end
