defmodule Farmbot.Supervisor do
  require Logger
  use Supervisor

  def init(%{target: target, compat_version: compat_version,
                      version: version, env: env}) do
    children = [
      # worker(Farmbot.Logger, [[]], restart: :permanent),
      # Storage that needs to persist across reboots.
      worker(SafeStorage, [env], restart: :permanent),
      worker(SSH, [env], restart: :permanent),

      # handles communications between bot and arduino
      supervisor(Farmbot.Serial.Supervisor, [env], restart: :permanent ),

      # Handles tracking of various parts of the bots state.
      supervisor(Farmbot.BotState.Supervisor,
        [%{target: target, compat_version: compat_version,
           version: version, env: env}],
      restart: :permanent),

      # Handle communications betwen bot and api
      worker(Farmbot.Sync, [[]], restart: :permanent ),

      # Just handles Farmbot scheduler stuff.
      worker(Farmbot.Scheduler, [[]], restart: :permanent ),

      # Handles Communication between the bot and frontend
      supervisor(RPC.Supervisor, [[]], restart: :permanent )
    ]
    opts = [strategy: :one_for_one, name: Farmbot.Supervisor]
    supervise(children, opts)
  end

  def start_link(args) do
    Logger.debug("Starting Farmbot")
    Supervisor.start_link(__MODULE__, args)
  end
end
