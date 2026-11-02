defmodule Exirc.IRC.Registration do
  @moduledoc """
  Builds the messages a client sends to register an IRC connection.
  """

  alias Exirc.IRC.Message

  @doc """
  Returns the registration messages in the order they must be sent.
  """
  def messages(registration) do
    nick = Map.get(registration, :nick)
    username = Map.get(registration, :username)
    realname = Map.get(registration, :realname)
    password = Map.get(registration, :password)

    [pass_command(password), nick_command(nick), user_command(username, realname)]
    |> Enum.reject(&is_nil/1)
  end

  defp pass_command(nil), do: nil
  defp pass_command(password), do: %Message{command: "PASS", params: [password]}

  defp nick_command(nick), do: %Message{command: "NICK", params: [nick]}

  defp user_command(username, realname),
    do: %Message{command: "USER", params: [username, "0", "*", realname]}
end
