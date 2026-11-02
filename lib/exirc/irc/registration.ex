defmodule Exirc.IRC.Registration do
  @moduledoc """
  Registers a client on an IRC connection.
  """

  alias Exirc.IRC.Message
  alias Exirc.IRC.Connection

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
  def register(connection, registration) do
    registration
    |> Map.new()
    |> messages()
    |> Enum.each(fn msg -> Connection.send_message(connection, msg) end)

    await_welcome(connection)
  end

  defp await_welcome(connection) do
    {:ok, connection, message} = Connection.recv_message(connection)

    case message do
      %Message{command: "001"} -> {:ok, connection, message}
      _other -> await_welcome(connection)
    end
  end

  defp pass_command(nil), do: nil
  defp pass_command(password), do: %Message{command: "PASS", params: [password]}

  defp nick_command(nick), do: %Message{command: "NICK", params: [nick]}

  defp user_command(username, realname),
    do: %Message{command: "USER", params: [username, "0", "*", realname]}
end
