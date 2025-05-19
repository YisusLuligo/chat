# Script para iniciar el servidor de chat
# Ejecutar con: elixir -S mix run start_server.exs

# Iniciar la aplicación y asegurar que existe el directorio de datos
File.mkdir_p!("datos_chat")
Application.ensure_all_started(:chat_app)

IO.puts("\n===== INICIANDO SERVIDOR DE CHAT =====")

# Obtener la IP local
ip_local = ChatUtils.obtener_ip_local()
IO.puts("IP local detectada: #{ip_local}")

# Verificar si el nodo ya tiene nombre
unless Node.alive?() do
  # Generar un nombre de nodo para el servidor
  nombre_nodo = "chat_server@#{ip_local}"

  # Iniciar el nodo con nombre
  case Node.start(String.to_atom(nombre_nodo), :shortnames) do
    {:ok, _} ->
      IO.puts("Nodo iniciado correctamente como: #{nombre_nodo}")
    {:error, reason} ->
      IO.puts("Error al iniciar nodo: #{inspect(reason)}")
      IO.puts("Intente iniciar manualmente con: iex --name #{nombre_nodo} --cookie chat_secret -S mix")
      System.halt(1)
  end

  # Configurar la cookie para seguridad
  Node.set_cookie(:chat_secret)
  IO.puts("Cookie de seguridad establecida: chat_secret")
end

# Verificar estado del nodo
IO.puts("\nEstado del nodo:")
IO.puts("  Nombre: #{Node.self()}")
IO.puts("  Cookie: #{Node.get_cookie()}")

# Iniciar el servidor de chat
IO.puts("\nIniciando servidor de chat...")
case ChatServer.iniciar() do
  {:ok, pid} ->
    IO.puts("Servidor de chat iniciado correctamente con PID: #{inspect(pid)}")
    IO.puts("\n===== SERVIDOR LISTO =====")
    IO.puts("Los clientes pueden conectarse usando:")
    IO.puts("  elixir -S mix run start_client.exs #{ip_local}")
    IO.puts("\nPresiona Ctrl+C dos veces para detener el servidor.")

    # Mostrar información de conexión para clientes
    IO.puts("\nInformación de conexión para clientes:")
    IO.puts("  Nodo: #{Node.self()}")
    IO.puts("  Cookie: chat_secret")

    # Mantener el script en ejecución
    Process.sleep(:infinity)

  {:error, {:already_started, pid}} ->
    IO.puts("El servidor de chat ya está en ejecución con PID: #{inspect(pid)}")
    IO.puts("\n===== SERVIDOR YA ACTIVO =====")
    IO.puts("Los clientes pueden conectarse usando:")
    IO.puts("  elixir -S mix run start_client.exs #{ip_local}")

    # Mantener el script en ejecución
    Process.sleep(:infinity)

  {:error, reason} ->
    IO.puts("Error al iniciar el servidor de chat: #{inspect(reason)}")
    IO.puts("Intente reiniciar la aplicación.")
    System.halt(1)
end
