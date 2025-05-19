defmodule ChatApp do
  @moduledoc """
  Módulo principal de la aplicación de chat.
  Proporciona funciones para iniciar el servidor y cliente.
  """
  require Logger

  @doc """
  Inicia el servidor de chat en el nodo actual.
  Configura el nodo como distribuido si no lo está ya.
  """
  def iniciar_servidor do
    # Verificar si el nodo ya tiene nombre
    unless Node.alive?() do
      # Obtener la IP local
      ip = ChatUtils.obtener_ip_local()

      # Generar un nombre de nodo
      nombre_nodo = "chat_server@#{ip}"

      # Iniciar el nodo con nombre
      Node.start(String.to_atom(nombre_nodo), :shortnames)

      # Configurar la cookie para seguridad
      Node.set_cookie(:chat_secret)

      Logger.info("Nodo del servidor iniciado como #{nombre_nodo}")
      IO.puts("Nodo del servidor iniciado como #{nombre_nodo}")
    end

    # Asegurar que el directorio de datos exista
    ChatUtils.asegurar_directorio_datos()

    # Iniciar el servidor de chat
    case ChatServer.iniciar() do
      {:ok, pid} ->
        Logger.info("Servidor de chat iniciado con PID #{inspect(pid)}")
        IO.puts("Servidor de chat iniciado correctamente.")
        IO.puts("Los clientes pueden conectarse a este nodo: #{Node.self()}")
        IO.puts("Utilizando la cookie: chat_secret")
        :ok
      {:error, {:already_started, pid}} ->
        Logger.info("El servidor de chat ya está en ejecución con PID #{inspect(pid)}")
        IO.puts("El servidor de chat ya está en ejecución.")
        :ok
      {:error, reason} ->
        Logger.error("Error al iniciar el servidor: #{inspect(reason)}")
        IO.puts("Error al iniciar el servidor: #{inspect(reason)}")
        :error
    end
  end

  @doc """
  Inicia un cliente de chat y conecta al servidor especificado.

  ## Parámetros

    * `ip_servidor` - Dirección IP del servidor de chat.
  """
  def iniciar_cliente(ip_servidor) do
    # Verificar si el nodo ya tiene nombre
    unless Node.alive?() do
      # Obtener la IP local
      ip = ChatUtils.obtener_ip_local()

      # Generar un nombre de nodo único basado en timestamp
      timestamp = :os.system_time(:millisecond)
      nombre_nodo = "chat_client_#{timestamp}@#{ip}"

      # Iniciar el nodo con nombre
      Node.start(String.to_atom(nombre_nodo), :shortnames)

      # Configurar la cookie para seguridad
      Node.set_cookie(:chat_secret)

      Logger.info("Nodo del cliente iniciado como #{nombre_nodo}")
      IO.puts("Nodo del cliente iniciado como #{nombre_nodo}")
    end

    # Iniciar el cliente y conectar al servidor
    ChatClient.iniciar(ip_servidor)
  end
end
