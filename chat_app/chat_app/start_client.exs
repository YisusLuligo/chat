# Script para iniciar el cliente de chat
# Ejecutar con: elixir -S mix run start_client.exs IP_SERVIDOR
# Ejemplo: elixir -S mix run start_client.exs 192.168.1.100

# Iniciar la aplicación
Application.ensure_all_started(:chat_app)

# Obtener la IP del servidor de los argumentos
args = System.argv()
ip_servidor = if length(args) > 0, do: List.first(args), else: nil

if is_nil(ip_servidor) do
  IO.puts("\nError: Debe especificar la IP del servidor.")
  IO.puts("Uso: elixir -S mix run start_client.exs IP_SERVIDOR")
  IO.puts("Ejemplo: elixir -S mix run start_client.exs 192.168.1.100")
  System.halt(1)
else
  IO.puts("\n===== INICIANDO CLIENTE DE CHAT =====")
  IO.puts("Conectando al servidor en: #{ip_servidor}")

  # Obtener la IP local para el cliente
  ip_local = ChatUtils.obtener_ip_local()
  IO.puts("IP local del cliente: #{ip_local}")

  # Generar un nombre único para el nodo cliente
  random_id = :rand.uniform(999999)
  nombre_nodo = "chat_client_#{random_id}@#{ip_local}"

  # Iniciar el nodo con nombre
  unless Node.alive?() do
    case Node.start(String.to_atom(nombre_nodo), :shortnames) do
      {:ok, _} ->
        IO.puts("Nodo cliente iniciado como: #{nombre_nodo}")
      {:error, reason} ->
        IO.puts("Error al iniciar nodo cliente: #{inspect(reason)}")
        System.halt(1)
    end

    # Configurar la cookie para seguridad
    Node.set_cookie(:chat_secret)
    IO.puts("Cookie de seguridad establecida: chat_secret")
  end

  # Intentar conectar al servidor
  nodo_servidor = :"chat_server@#{ip_servidor}"

  case Node.connect(nodo_servidor) do
    true ->
      IO.puts("\nConexión exitosa al servidor: #{nodo_servidor}")
      # Obtener referencia al servidor de chat
      servidor_pid = :global.whereis_name(:chat_servidor)

      if servidor_pid == :undefined do
        IO.puts("Error: No se pudo encontrar el proceso del servidor de chat.")
        IO.puts("Asegúrese de que el servidor esté iniciado correctamente.")
        System.halt(1)
      else
        IO.puts("Servidor de chat encontrado, iniciando sesión...")
        # Iniciar el cliente
        ChatClient.mostrar_menu_principal(servidor_pid, nodo_servidor)
      end

    false ->
      IO.puts("\nError: No se pudo conectar al servidor en #{nodo_servidor}")
      IO.puts("Verifique que:")
      IO.puts("  1. El servidor esté en ejecución")
      IO.puts("  2. La dirección IP del servidor sea correcta")
      IO.puts("  3. Ambas máquinas estén en la misma red")
      IO.puts("  4. No haya firewalls bloqueando la conexión")
      IO.puts("  5. La cookie de seguridad sea 'chat_secret'")
      System.halt(1)
  end
end
