defmodule Exirc.IRC.Registration do
  @moduledoc """
  Registers a client on an IRC connection.
  """

  alias Exirc.IRC.Message

  @doc """
  Returns the registration messages in the order they must be sent.
  """
  def messages(%{nick: nick, username: username, realname: realname} = registration) do
    password = Map.get(registration, :password)

    [pass_command(password), nick_command(nick), user_command(username, realname)]
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Sends the registration messages over `connection` and waits for the
  server's welcome reply (`001`).
  """
  def register(_connection, _registration) do
    raise "not implemented"
  end

  defp pass_command(nil), do: nil
  defp pass_command(password), do: %Message{command: "PASS", params: [password]}

  defp nick_command(nick), do: %Message{command: "NICK", params: [nick]}

  defp user_command(username, realname),
    do: %Message{command: "USER", params: [username, "0", "*", realname]}
end
