defmodule ChatSession do
  @moduledoc """
  Gestiona la sesión interactiva de chat para un cliente.
  """
  require Logger

  @doc """
  Inicia una sesión de chat para un usuario autenticado.
  """
  def iniciar_sesion(servidor_pid, username, nodo_servidor) do
    # Configurar para recibir mensajes
    Process.flag(:trap_exit, true)

    # Mostrar las salas disponibles
    mostrar_opciones_salas(servidor_pid, username, nodo_servidor)
  end

  @doc """
  Muestra las opciones de salas disponibles.
  """
  def mostrar_opciones_salas(servidor_pid, username, nodo_servidor) do
    # Obtener las salas disponibles
    salas = GenServer.call(servidor_pid, :listar_salas)

    IO.puts("\n===== SALAS DE CHAT =====")
    IO.puts("Usuario actual: #{username}")
    IO.puts("Salas disponibles:")

    if Enum.empty?(salas) do
      IO.puts("  No hay salas disponibles.")
    else
      Enum.with_index(salas, 1) |> Enum.each(fn {sala, indice} ->
        IO.puts("  #{indice}. #{sala}")
      end)
    end

    IO.puts("  #{length(salas) + 1}. Crear nueva sala")
    IO.puts("  #{length(salas) + 2}. Salir")

    # Solicitar selección al usuario
    opcion = IO.gets("\nSeleccione una opción: ") |> String.trim()
    manejar_seleccion_sala(opcion, salas, servidor_pid, username, nodo_servidor)
  end

  @doc """
  Maneja la selección de sala del usuario.
  """
  def manejar_seleccion_sala(opcion, salas, servidor_pid, username, nodo_servidor) do
    case Integer.parse(opcion) do
      {num, _} when num >= 1 and num <= length(salas) ->
        # Unirse a sala existente
        sala_seleccionada = Enum.at(salas, num - 1)
        unirse_a_sala(servidor_pid, sala_seleccionada, username, nodo_servidor)

      {num, _} when num == length(salas) + 1 ->
        # Crear nueva sala
        nueva_sala = IO.gets("Nombre de la nueva sala: ") |> String.trim()
        crear_sala(servidor_pid, nueva_sala, username, nodo_servidor)

      {num, _} when num == length(salas) + 2 ->
        # Salir
        IO.puts("Saliendo del chat...")
        System.halt(0)

      _ ->
        IO.puts("Opción inválida. Intente de nuevo.")
        mostrar_opciones_salas(servidor_pid, username, nodo_servidor)
    end
  end

  @doc """
  Crea una nueva sala y se une a ella.
  """
  def crear_sala(servidor_pid, nombre_sala, username, nodo_servidor) do
    case GenServer.call(servidor_pid, {:crear_sala, username, nombre_sala}) do
      :ok ->
        IO.puts("Sala '#{nombre_sala}' creada exitosamente.")
        iniciar_sala_chat(servidor_pid, nombre_sala, username, nodo_servidor)

      {:error, :sala_existente} ->
        IO.puts("Ya existe una sala con ese nombre. Intente con otro nombre.")
        mostrar_opciones_salas(servidor_pid, username, nodo_servidor)

      {:error, razon} ->
        IO.puts("Error al crear sala: #{inspect(razon)}")
        mostrar_opciones_salas(servidor_pid, username, nodo_servidor)
    end
  end

  @doc """
  Une al usuario a una sala existente.
  """
  def unirse_a_sala(servidor_pid, nombre_sala, username, nodo_servidor) do
    case GenServer.call(servidor_pid, {:unirse_sala, username, nombre_sala}) do
      :ok ->
        IO.puts("Te has unido a la sala '#{nombre_sala}'.")
        iniciar_sala_chat(servidor_pid, nombre_sala, username, nodo_servidor)

      {:error, razon} ->
        IO.puts("Error al unirse a la sala: #{inspect(razon)}")
        mostrar_opciones_salas(servidor_pid, username, nodo_servidor)
    end
  end

  @doc """
  Inicia la interfaz de chat en una sala.
  """
  def iniciar_sala_chat(servidor_pid, nombre_sala, username, nodo_servidor) do
    # Mostrar historial de mensajes
    mensajes = GenServer.call(servidor_pid, {:obtener_historial, nombre_sala})

    if not Enum.empty?(mensajes) do
      IO.puts("\nHistorial de mensajes:")
      Enum.each(mensajes, fn {from, mensaje, timestamp} ->
        # Formatear timestamp
        hora_formateada = ChatUtils.formatear_timestamp(timestamp)
        if from == username do
          IO.puts("\e[36m[#{hora_formateada}] TÚ: #{mensaje}\e[0m")  # Azul claro
        else
          IO.puts("[#{hora_formateada}] #{from}: #{mensaje}")
        end
      end)
      IO.puts("")
    end

    IO.puts("\nEscribe tus mensajes. Comandos disponibles:")
    IO.puts("  /usuarios - Mostrar usuarios conectados")
    IO.puts("  /volver - Volver al menú de salas")
    IO.puts("  /historial - Ver historial de mensajes")
    IO.puts("  /estado - Verificar estado de la conexión")
    IO.puts("  /ayuda - Mostrar esta ayuda")
    IO.puts("  /salir - Salir del chat")

    bucle_chat(servidor_pid, nombre_sala, username, nodo_servidor)
  end

  @doc """
  Bucle principal de chat en una sala.
  """
  def bucle_chat(servidor_pid, nombre_sala, username, nodo_servidor) do
  # Monitorear el nodo del servidor
  Node.monitor(nodo_servidor, true)

  # Procesar mensajes entrantes
  procesar_mensajes_pendientes(servidor_pid, nombre_sala, username, nodo_servidor)

  # Verificar si el servidor sigue conectado
  if Node.ping(nodo_servidor) != :pong do
    IO.puts("\r\e[31m[ERROR] Se ha perdido la conexión con el servidor\e[0m")
    manejar_reconexion(servidor_pid, username, nodo_servidor, nombre_sala)
    # No continuamos con el resto de la función
  else
    # Solicitar entrada al usuario
    input = IO.gets("[#{nombre_sala}]> ") |> String.trim()

    case input do
      "/salir" ->
        IO.puts("Saliendo del chat...")
        System.halt(0)

      "/volver" ->
        mostrar_opciones_salas(servidor_pid, username, nodo_servidor)

      "/usuarios" ->
        try do
          usuarios = GenServer.call(servidor_pid, :listar_usuarios)
          IO.puts("\nUsuarios conectados:")
          Enum.each(usuarios, fn user ->
            if user == username do
              IO.puts("  - #{user} (TÚ)")
            else
              IO.puts("  - #{user}")
            end
          end)
        rescue
          e ->
            IO.puts("\r\e[31m[ERROR] No se pudo obtener la lista de usuarios: #{inspect(e)}\e[0m")
        end
        bucle_chat(servidor_pid, nombre_sala, username, nodo_servidor)

      "/historial" ->
        try do
          mensajes = GenServer.call(servidor_pid, {:obtener_historial, nombre_sala})
          IO.puts("\nHistorial de mensajes:")
          if Enum.empty?(mensajes) do
            IO.puts("  No hay mensajes.")
          else
            Enum.each(mensajes, fn {from, mensaje, timestamp} ->
              hora_formateada = ChatUtils.formatear_timestamp(timestamp)
              if from == username do
                IO.puts("\e[36m[#{hora_formateada}] TÚ: #{mensaje}\e[0m")  # Azul claro
              else
                IO.puts("[#{hora_formateada}] #{from}: #{mensaje}")
              end
            end)
          end
        rescue
          e ->
            IO.puts("\r\e[31m[ERROR] No se pudo obtener el historial: #{inspect(e)}\e[0m")
        end
        bucle_chat(servidor_pid, nombre_sala, username, nodo_servidor)

      "/ayuda" ->
        IO.puts("\nComandos disponibles:")
        IO.puts("  /usuarios - Mostrar usuarios conectados")
        IO.puts("  /volver - Volver al menú de salas")
        IO.puts("  /historial - Ver historial de la sala actual")
        IO.puts("  /estado - Verificar estado de la conexión")
        IO.puts("  /ayuda - Mostrar esta ayuda")
        IO.puts("  /salir - Salir del chat")
        bucle_chat(servidor_pid, nombre_sala, username, nodo_servidor)

      "/estado" ->
        # Nuevo comando para verificar estado de conexión
        node_status = Node.ping(nodo_servidor)
        server_status = if :global.whereis_name(:chat_servidor) != :undefined, do: "activo", else: "no encontrado"

        IO.puts("\nEstado de la conexión:")
        IO.puts("  Nodo cliente: #{Node.self()}")
        IO.puts("  Nodo servidor: #{nodo_servidor} (#{node_status})")
        IO.puts("  Servidor de chat: #{server_status}")
        IO.puts("  Nodos conectados: #{inspect Node.list()}")
        bucle_chat(servidor_pid, nombre_sala, username, nodo_servidor)

      mensaje ->
        # Enviar mensaje con manejo de errores
        try do
          GenServer.cast(servidor_pid, {:enviar_mensaje, username, nombre_sala, mensaje})
          # NO mostrar el historial aquí - los mensajes se actualizarán mediante procesar_mensajes_pendientes
        rescue
          e ->
            IO.puts("\r\e[31m[ERROR] No se pudo enviar el mensaje: #{inspect(e)}\e[0m")
        catch
          :exit, reason ->
            IO.puts("\r\e[31m[ERROR] Error al enviar el mensaje: #{inspect(reason)}\e[0m")
            # Intentar reconectar si hay problemas
            case reason do
              {:nodedown, ^nodo_servidor} ->
                manejar_reconexion(servidor_pid, username, nodo_servidor, nombre_sala)
              {:timeout, _} ->
                manejar_reconexion(servidor_pid, username, nodo_servidor, nombre_sala)
              _ ->
                bucle_chat(servidor_pid, nombre_sala, username, nodo_servidor)
            end
        end

        # Procesar mensajes entrantes - esto mostrará cualquier mensaje nuevo, incluido el que acabamos de enviar
        procesar_mensajes_pendientes(servidor_pid, nombre_sala, username, nodo_servidor)

        bucle_chat(servidor_pid, nombre_sala, username, nodo_servidor)
    end
  end
end

  @doc """
  Maneja la reconexión en caso de desconexión.
  """
  def manejar_reconexion(_servidor_pid, username, nodo_servidor, nombre_sala) do
    IO.puts("\n[!] Conexión perdida con el servidor. Intentando reconectar...")

    # Intentar reconectar hasta 5 veces
    reconectado = Enum.reduce_while(1..5, false, fn intento, _ ->
      IO.puts("Intento de reconexión #{intento}/5...")
      Process.sleep(2000 * intento)  # Espera incremental

      # Primero intentar reconectar al nodo
      node_status = Node.ping(nodo_servidor)

      if node_status == :pong do
        # El nodo está disponible, intentar reconectar con el servidor
        servidor_actual = :global.whereis_name(:chat_servidor)

        if servidor_actual != :undefined do
          # Servidor encontrado, intentar reautenticar
          try do
            case GenServer.call(servidor_actual, {:autenticar, username, "", self(), Node.self()}) do
              {:ok, _} ->
                IO.puts("Reconexión exitosa!")
                {:halt, true}
              _ ->
                IO.puts("Error: No se pudo autenticar con el servidor.")
                {:cont, false}
            end
          rescue
            e ->
              IO.puts("Error de comunicación: #{inspect(e)}")
              {:cont, false}
          end
        else
          IO.puts("Error: Nodo conectado pero servidor no encontrado.")
          {:cont, false}
        end
      else
        IO.puts("Error: Nodo del servidor no disponible.")
        {:cont, false}
      end
    end)

    unless reconectado do
      IO.puts("\n[X] No se pudo reconectar. Saliendo...")
      System.halt(1)
    end

    # Si reconectamos exitosamente y teníamos una sala activa, volver a unirse
    if nombre_sala do
      try do
        GenServer.call(:global.whereis_name(:chat_servidor), {:unirse_sala, username, nombre_sala})
        IO.puts("Volviendo a la sala #{nombre_sala}...")
        iniciar_sala_chat(:global.whereis_name(:chat_servidor), nombre_sala, username, nodo_servidor)
      rescue
        e ->
          IO.puts("Error al volver a la sala: #{inspect(e)}")
          mostrar_opciones_salas(:global.whereis_name(:chat_servidor), username, nodo_servidor)
      end
    else
      mostrar_opciones_salas(:global.whereis_name(:chat_servidor), username, nodo_servidor)
    end
  end

  # Procesa mensajes pendientes
  defp procesar_mensajes_pendientes(servidor_pid, nombre_sala, username, nodo_servidor) do
  # Configuración para asegurar que se procesen todos los mensajes correctamente
    flush_all_messages(servidor_pid, nombre_sala, username, nodo_servidor)
    receive do
    {:procesar_mensajes, sala} ->
      # Realizar acciones específicas para procesar mensajes
      IO.puts("\r\e[33m[SISTEMA] Procesando mensajes de la sala #{sala}\e[0m")
      procesar_mensajes_pendientes(servidor_pid, nombre_sala, username, nodo_servidor)

    # Otros casos existentes...
  after 0 ->
    :ok
  end
  end

# Función recursiva para procesar todos los mensajes pendientes
defp flush_all_messages(servidor_pid, nombre_sala, username, nodo_servidor) do
  receive do
    {:mensaje_chat, sala, from, mensaje, timestamp} ->
      # Formatear timestamp
      hora_formateada = ChatUtils.formatear_timestamp(timestamp)

      # Imprimir con formato para distinguir mejor los mensajes
      if from == username do
        IO.puts("\r\e[36m[#{sala}][#{hora_formateada}] TÚ: #{mensaje}\e[0m")  # Azul claro
      else
        IO.puts("\r\e[32m[#{sala}][#{hora_formateada}] #{from}: #{mensaje}\e[0m")  # Verde
      end

      IO.write("[#{nombre_sala}]> ")  # Volver a mostrar el prompt
      flush_all_messages(servidor_pid, nombre_sala, username, nodo_servidor)

    {:mensaje_sistema, mensaje} ->
      IO.puts("\r\e[33m[SISTEMA] #{mensaje}\e[0m")  # Amarillo
      IO.write("[#{nombre_sala}]> ")  # Volver a mostrar el prompt
      flush_all_messages(servidor_pid, nombre_sala, username, nodo_servidor)

    {:EXIT, _pid, reason} ->
      IO.puts("\r\e[31m[ERROR] La conexión se ha interrumpido: #{inspect(reason)}\e[0m")
      manejar_reconexion(servidor_pid, username, nodo_servidor, nombre_sala)

    {:nodedown, node} ->
      IO.puts("\r\e[31m[ERROR] El nodo #{node} se ha desconectado\e[0m")
      if node == nodo_servidor do
        manejar_reconexion(servidor_pid, username, nodo_servidor, nombre_sala)
      else
        IO.write("[#{nombre_sala}]> ")  # Volver a mostrar el prompt
        flush_all_messages(servidor_pid, nombre_sala, username, nodo_servidor)
      end

    other ->
      IO.puts("\r[Recibido] #{inspect(other)}")
      flush_all_messages(servidor_pid, nombre_sala, username, nodo_servidor)

  after 0 ->
    :ok  # No hay más mensajes pendientes
  end
end
end
