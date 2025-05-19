defmodule ChatPersistence do
  @moduledoc """
  Módulo para manejar la persistencia de datos del chat.
  """
  require Logger

  @archivos_path "datos_chat"

  @doc """
  Inicializa el sistema de persistencia.
  """
  def inicializar do
    File.mkdir_p!(@archivos_path)
    :ok
  end

  @doc """
  Guarda mensajes de una sala en formato CSV.
  """
  def guardar_mensajes_csv(nombre_sala, mensajes) do
    # Asegurar que el directorio existe
    File.mkdir_p!(@archivos_path)

    # Ruta del archivo
    ruta_archivo = Path.join(@archivos_path, "#{nombre_sala}_mensajes.csv")

    # Convertir mensajes a formato CSV
    cabecera = "usuario,mensaje,timestamp\n"
    contenido = Enum.reduce(mensajes, cabecera, fn {usuario, mensaje, timestamp}, acc ->
      # Formatear timestamp
      hora_formateada = ChatUtils.formatear_timestamp(timestamp)

      # Escapar comillas en el mensaje
      mensaje_escapado = String.replace(mensaje, "\"", "\"\"")

      # Añadir línea CSV
      acc <> "#{usuario},\"#{mensaje_escapado}\",#{hora_formateada}\n"
    end)

    # Guardar en archivo
    case File.write(ruta_archivo, contenido) do
      :ok -> {:ok, ruta_archivo}
      {:error, razon} ->
        Logger.error("Error al guardar mensajes CSV: #{inspect(razon)}")
        {:error, razon}
    end
  end

  @doc """
  Carga mensajes de una sala desde un archivo CSV.
  """
  def cargar_mensajes_csv(nombre_sala) do
    # Ruta del archivo
    ruta_archivo = Path.join(@archivos_path, "#{nombre_sala}_mensajes.csv")

    # Verificar si el archivo existe
    case File.read(ruta_archivo) do
      {:ok, contenido} ->
        # Dividir en líneas y quitar cabecera
        [_cabecera | lineas] = String.split(contenido, "\n")

        # Convertir cada línea a un mensaje
        mensajes = Enum.map(lineas, fn linea ->
          if String.trim(linea) != "" do
            # Parsear la línea CSV
            [usuario, mensaje, timestamp] = parse_csv_line(linea)

            # Convertir timestamp a número
            timestamp_num = parse_timestamp(timestamp)

            {usuario, mensaje, timestamp_num}
          end
        end)

        # Filtrar posibles nil
        {:ok, Enum.filter(mensajes, &(&1 != nil))}

      {:error, :enoent} ->
        # Archivo no existe
        {:ok, []}

      {:error, razon} ->
        Logger.error("Error al cargar mensajes CSV: #{inspect(razon)}")
        {:error, razon}
    end
  end

  @doc """
  Exporta todo el historial de mensajes a archivos CSV.
  """
  def exportar_historial_completo(mensajes_por_sala) do
    # Asegurar que el directorio existe
    File.mkdir_p!(@archivos_path)

    # Exportar cada sala
    Enum.map(mensajes_por_sala, fn {nombre_sala, mensajes} ->
      guardar_mensajes_csv(nombre_sala, mensajes)
    end)
  end

  # Función para parsear una línea CSV con manejo de campos entre comillas
  defp parse_csv_line(linea) do
    # Implementación básica de parser CSV
    # Nota: Para casos reales, se recomienda usar una biblioteca como NimbleCSV

    # Para simplificar, asumimos que los campos son: usuario, mensaje (posiblemente con comas), timestamp
    case Regex.run(~r/^([^,]+),"([^"]*(?:"[^"]*"[^"]*)*)","?([^,"]+)"?$/, linea) do
      [_, usuario, mensaje, timestamp] ->
        # Desescapar comillas dobles en el mensaje
        mensaje_limpio = String.replace(mensaje, "\"\"", "\"")
        [usuario, mensaje_limpio, timestamp]
      _ ->
        # Fallback para líneas simples sin comillas
        String.split(linea, ",", parts: 3)
    end
  end

  # Convierte un timestamp en formato string a milisegundos
  defp parse_timestamp(timestamp_str) do
    # Formato esperado: "YYYY-MM-DD HH:MM:SS"
    try do
      # Parsear componentes
      [fecha, hora] = String.split(timestamp_str, " ")
      [año, mes, dia] = String.split(fecha, "-") |> Enum.map(&String.to_integer/1)
      [hora, minuto, segundo] = String.split(hora, ":") |> Enum.map(&String.to_integer/1)

      # Convertir a timestamp
      {{año, mes, dia}, {hora, minuto, segundo, 0}}
      |> :calendar.datetime_to_gregorian_seconds()
      |> Kernel.-(62167219200) # Restar segundos entre año 0 y 1970
      |> Kernel.*(1000) # Convertir a milisegundos
    rescue
      _ -> :os.system_time(:millisecond) # En caso de error, usar el tiempo actual
    end
  end
end
