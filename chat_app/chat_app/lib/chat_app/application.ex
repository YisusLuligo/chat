defmodule ChatApp.Application do
  @moduledoc """
  Punto de entrada de la aplicación para iniciar con mix.
  """
  use Application
  require Logger  # Añadir esta línea para poder usar Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Iniciando aplicación ChatApp...")

    # Crear directorio para datos si no existe
    File.mkdir_p!("datos_chat")

    children = [
      # No iniciamos el servidor automáticamente para permitir
      # que el usuario lo inicie manualmente con ChatApp.iniciar_servidor()
    ]

    opts = [strategy: :one_for_one, name: ChatApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
