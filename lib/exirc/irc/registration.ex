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

    registration_messages =
      registration
      |> Map.new()
      |> messages()

    case send_messages(connection, registration_messages) do
      {:ok, connection} -> await_welcome(connection, deadline)
      {:error, reason} -> close_with_error(connection, reason)
    end
  end

  defp send_messages(connection, []), do: {:ok, connection}

  defp send_messages(connection, [message | rest]) do
    with {:ok, connection} <- Connection.send_message(connection, message) do
      send_messages(connection, rest)
    end
  end

  defp await_welcome(connection, deadline) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    case Connection.recv_message(connection, remaining) do
      {:ok, connection, %Message{command: "PING", params: params}} ->
        pong = %Message{command: "PONG", params: params}

        case send_messages(connection, [pong]) do
          {:ok, connection} -> await_welcome(connection, deadline)
          {:error, reason} -> close_with_error(connection, reason)
        end

      {:ok, connection, %Message{command: "001"} = message} ->
        {:ok, connection, message}

      {:ok, connection, %Message{command: "433", params: [_, nick | _]}} ->
        close_with_error(connection, {:nickname_in_use, nick})

      {:ok, connection, %Message{command: "464"}} ->
        close_with_error(connection, :password_mismatch)

      {:ok, connection, %Message{command: "ERROR", params: [error_message]}} ->
        close_with_error(connection, {:server_error, error_message})

      {:ok, connection, _other} ->
        await_welcome(connection, deadline)

      {:error, reason} ->
        close_with_error(connection, reason)
    end
  end

  defp close_with_error(connection, reason) do
    Connection.close(connection)
    {:error, reason}
  end

  defp pass_command(nil), do: nil
  defp pass_command(password), do: %Message{command: "PASS", params: [password]}

  defp nick_command(nick), do: %Message{command: "NICK", params: [nick]}

  defp user_command(username, realname),
    do: %Message{command: "USER", params: [username, "0", "*", realname]}
end
