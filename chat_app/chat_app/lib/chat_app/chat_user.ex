defmodule ChatUser do
  @moduledoc """
  Estructura para almacenar información de usuarios.
  """

  @doc """
  Define la estructura de usuario con valores por defecto.
  """
  defstruct nombre: "",
            password_hash: "",
            ultima_conexion: nil

  @doc """
  Crea una nueva estructura de usuario.
  """
  def crear(nombre, password) do
    password_hash = :crypto.hash(:sha256, password) |> Base.encode16()
    %ChatUser{
      nombre: nombre,
      password_hash: password_hash,
      ultima_conexion: :os.system_time(:millisecond)
    }
  end

  @doc """
  Verifica si las credenciales proporcionadas son correctas.
  """
  def credenciales_validas?(usuario, password) do
    password_hash = :crypto.hash(:sha256, password) |> Base.encode16()
    usuario.password_hash == password_hash
  end

  @doc """
  Actualiza la última conexión del usuario.
  """
  def actualizar_conexion(usuario) do
    %ChatUser{usuario | ultima_conexion: :os.system_time(:millisecond)}
  end

  @doc """
  Convierte la estructura a formato de cadena para impresión.
  """
  def a_cadena(usuario) do
    hora_formateada = if usuario.ultima_conexion do
      ChatUtils.formatear_timestamp(usuario.ultima_conexion)
    else
      "Nunca"
    end

    "Usuario: #{usuario.nombre} (Última conexión: #{hora_formateada})"
  end
end
