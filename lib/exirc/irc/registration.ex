defmodule Exirc.IRC.Registration do
  @moduledoc """
  Registers a client on an IRC connection.
  """

  alias Exirc.IRC.Message
  alias Exirc.IRC.Connection

  # Time allowed for the whole registration, in milliseconds.
  @default_timeout 30_000

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

  def register(connection, registration, opts \\ [])

  def register(connection, registration, opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    deadline = System.monotonic_time(:millisecond) + timeout

    registration
    |> Map.new()
    |> messages()
    |> Enum.each(fn msg -> Connection.send_message(connection, msg) end)

    await_welcome(connection, deadline)
  end

  defp await_welcome(connection, deadline) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    case Connection.recv_message(connection, remaining) do
      {:ok, connection, message} ->
        case message do
          %Message{command: "PING", params: params} ->
            Connection.send_message(connection, %Message{command: "PONG", params: params})
            await_welcome(connection, deadline)

          %Message{command: "001"} ->
            {:ok, connection, message}

          %Message{command: "433", params: [_, nick | _]} ->
            Connection.close(connection)
            {:error, {:nickname_in_use, nick}}

          %Message{command: "464"} ->
            Connection.close(connection)
            {:error, :password_mismatch}

          %Message{command: "ERROR", params: [error_message]} ->
            Connection.close(connection)
            {:error, {:server_error, error_message}}

          _other ->
            await_welcome(connection, deadline)
        end

      error ->
        Connection.close(connection)
        error
    end
  end

  defp pass_command(nil), do: nil
  defp pass_command(password), do: %Message{command: "PASS", params: [password]}

  defp nick_command(nick), do: %Message{command: "NICK", params: [nick]}

  defp user_command(username, realname),
    do: %Message{command: "USER", params: [username, "0", "*", realname]}
end
