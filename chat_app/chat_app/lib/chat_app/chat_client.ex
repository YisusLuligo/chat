defmodule ChatClient do
  @moduledoc """
  Módulo cliente para conectarse al servidor de chat desde diferentes nodos.
  Proporciona funciones para autenticación, registro y gestión de sesiones.
  """
  require Logger

  @doc """
  Inicia el cliente de chat y maneja la conexión al servidor.

  ## Parámetros

    * `ip_servidor` - Dirección IP del servidor de chat.
    * `puerto` - Puerto opcional del servidor (por defecto 'chat_server').

  ## Ejemplos

      iex> ChatClient.iniciar("192.168.1.100")
      :ok

  """
  def iniciar(ip_servidor, puerto \\ "chat_server") do
    Logger.info("Iniciando cliente de chat...")

    # Configurar para recibir mensajes
    Process.flag(:trap_exit, true)

    # Construir el nombre del nodo del servidor
    nodo_servidor = :"#{puerto}@#{ip_servidor}"

    # Intentar conectar con el nodo del servidor
    case Node.connect(nodo_servidor) do
      true ->
        Logger.info("Conectado al servidor en #{nodo_servidor}")
        iniciar_sesion(nodo_servidor)
      false ->
        Logger.error("No se pudo conectar al servidor en #{nodo_servidor}")
        IO.puts("Error: No se pudo conectar al servidor en #{nodo_servidor}")
        IO.puts("Asegúrate de que el servidor esté en ejecución y que la cookie sea la misma.")
        :error
    end
  end

  @doc """
  Inicia la sesión de chat, ofreciendo opciones para registro o autenticación.

  ## Parámetros

    * `nodo_servidor` - Nombre del nodo del servidor.

  """
  def iniciar_sesion(nodo_servidor) do
    # Obtener la referencia al servidor
    servidor_pid = :global.whereis_name(:chat_servidor)

    if servidor_pid == :undefined do
      Logger.error("No se pudo encontrar el servidor en el nodo #{nodo_servidor}")
      IO.puts("Error: No se pudo encontrar el servidor de chat.")
      IO.puts("Asegúrate de que el servidor esté iniciado correctamente.")
      :error
    else
      mostrar_menu_principal(servidor_pid, nodo_servidor)
    end
  end

  @doc """
  Muestra el menú principal del cliente con opciones para iniciar sesión o registrarse.

  ## Parámetros

    * `servidor_pid` - PID del proceso del servidor.
    * `nodo_servidor` - Nombre del nodo del servidor.

  """
  def mostrar_menu_principal(servidor_pid, nodo_servidor) do
    IO.puts("\n===== CHAT DISTRIBUIDO =====")
    IO.puts("1. Iniciar sesión")
    IO.puts("2. Registrarse")
    IO.puts("3. Salir")

    case IO.gets("Seleccione una opción: ") |> String.trim() do
      "1" -> autenticar_usuario(servidor_pid, nodo_servidor)
      "2" -> registrar_usuario(servidor_pid, nodo_servidor)
      "3" ->
        IO.puts("Saliendo del chat...")
        :ok
      _ ->
        IO.puts("Opción inválida. Intente de nuevo.")
        mostrar_menu_principal(servidor_pid, nodo_servidor)
    end
  end

  @doc """
  Autentica a un usuario existente en el servidor.

  ## Parámetros

    * `servidor_pid` - PID del proceso del servidor.
    * `nodo_servidor` - Nombre del nodo del servidor.

  """
  def autenticar_usuario(servidor_pid, nodo_servidor) do
    username = IO.gets("Nombre de usuario: ") |> String.trim()
    password = IO.gets("Contraseña: ") |> String.trim()

    case GenServer.call(servidor_pid, {:autenticar, username, password, self(), Node.self()}) do
      {:ok, _} ->
        IO.puts("Autenticación exitosa. Bienvenido #{username}!")
        ChatSession.iniciar_sesion(servidor_pid, username, nodo_servidor)
      {:error, :auth_fallida} ->
        IO.puts("Error: Credenciales incorrectas.")
        mostrar_menu_principal(servidor_pid, nodo_servidor)
      {:error, reason} ->
        IO.puts("Error de autenticación: #{inspect(reason)}")
        mostrar_menu_principal(servidor_pid, nodo_servidor)
    end
  end

  @doc """
  Registra un nuevo usuario en el servidor.

  ## Parámetros

    * `servidor_pid` - PID del proceso del servidor.
    * `nodo_servidor` - Nombre del nodo del servidor.

  """
  def registrar_usuario(servidor_pid, nodo_servidor) do
    username = IO.gets("Nuevo nombre de usuario: ") |> String.trim()
    password = IO.gets("Nueva contraseña: ") |> String.trim()
    password_confirm = IO.gets("Confirmar contraseña: ") |> String.trim()

    if password != password_confirm do
      IO.puts("Error: Las contraseñas no coinciden.")
      registrar_usuario(servidor_pid, nodo_servidor)
    else
      case GenServer.call(servidor_pid, {:registrar_usuario, username, password, self(), Node.self()}) do
        {:ok, _} ->
          IO.puts("Registro exitoso. Bienvenido #{username}!")
          ChatSession.iniciar_sesion(servidor_pid, username, nodo_servidor)
        {:error, :usuario_existente} ->
          IO.puts("Error: El nombre de usuario ya existe.")
          mostrar_menu_principal(servidor_pid, nodo_servidor)
        {:error, reason} ->
          IO.puts("Error de registro: #{inspect(reason)}")
          mostrar_menu_principal(servidor_pid, nodo_servidor)
      end
    end
  end
end
