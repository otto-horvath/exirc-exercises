defmodule Exirc.Test.FakeIRCServer do
  @moduledoc """
  A deterministic local IRC server for tests.

  The server is driven step by step from the test process: accept the client,
  read the lines it sends, and reply with lines or raw bytes. It listens only
  on the loopback interface and asks the OS for a free port, so tests never
  depend on public networks and can run concurrently.

  Sockets are linked to the process that opened them, so they close when the
  test process exits.
  """

  import ExUnit.Assertions, only: [flunk: 1]

  @crlf "\r\n"
  @default_timeout 1_000

  defstruct [:listen_socket, :socket, :port]

  @doc """
  Starts listening on `127.0.0.1` with an OS-assigned port.
  """
  def listen do
    {:ok, listen_socket} =
      :gen_tcp.listen(0, [
        :binary,
        ip: {127, 0, 0, 1},
        packet: :line,
        active: false,
        reuseaddr: true
      ])

    {:ok, port} = :inet.port(listen_socket)

    %__MODULE__{listen_socket: listen_socket, port: port}
  end

  @doc """
  Waits for one client connection and returns the server ready to talk to it.
  """
  def accept(%__MODULE__{listen_socket: listen_socket} = server, timeout \\ @default_timeout) do
    case :gen_tcp.accept(listen_socket, timeout) do
      {:ok, socket} -> %{server | socket: socket}
      {:error, reason} -> flunk("fake IRC server accepted no client: #{inspect(reason)}")
    end
  end

  @doc """
  Reads the next line sent by the client and returns it without its CRLF.

  Fails the test if the client sends no line in time, closes the connection,
  or ends a line with something other than CRLF.
  """
  def recv_line(%__MODULE__{socket: socket}, timeout \\ @default_timeout) do
    case :gen_tcp.recv(socket, 0, timeout) do
      {:ok, line} ->
        if String.ends_with?(line, @crlf) do
          binary_part(line, 0, byte_size(line) - byte_size(@crlf))
        else
          flunk("fake IRC server expected a CRLF-terminated line, got: #{inspect(line)}")
        end

      {:error, reason} ->
        flunk("fake IRC server received no line: #{inspect(reason)}")
    end
  end

  @doc """
  Sends one IRC line to the client, adding CRLF.
  """
  def send_line(%__MODULE__{} = server, line), do: send_raw(server, line <> @crlf)

  @doc """
  Sends bytes to the client exactly as given, for split or coalesced lines.
  """
  def send_raw(%__MODULE__{socket: socket}, data) do
    :ok = :gen_tcp.send(socket, data)
  end

  @doc """
  Closes the client connection, simulating the server hanging up.
  """
  def close(%__MODULE__{socket: socket}) do
    :ok = :gen_tcp.close(socket)
  end
end
