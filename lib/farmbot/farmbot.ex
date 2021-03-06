defmodule Farmbot do
  @moduledoc """
    Main entry point to the application.
    Basically just starts some supervisors.
  """
  require Logger
  use Supervisor
  @state_path Application.get_env(:farmbot, :state_path)

  @doc """
    Shortcut to Nerves.Firmware.reboot
  """
  @spec reboot :: any
  def reboot do
    Nerves.Firmware.reboot
  end


  @doc """
    Shortcut to Nerves.Firmware.poweroff
  """
  @spec reboot :: any
  def poweroff do
    Nerves.Firmware.poweroff
  end

  @doc """
    Formats the sytem partition, and mounts as read/write
  """
  @spec format_state_part :: {:ok, atom}
  def format_state_part do
    Logger.warn("FORMATTING DATA PARTITION!")
    System.cmd("mkfs.ext4", ["/dev/mmcblk0p3", "-F"])
    System.cmd("mount", ["/dev/mmcblk0p3", "/state", "-t", "ext4"])
    File.write("/state/.formatted", "DONT CAT ME\n")
    {:ok, :pattern_matching_is_hard}
  end

  @doc """
    Checks for a .formatted file on the state/data partition, if it doesnt exist
    it formats the partition
  """
  @spec fs_init(:prod) :: {:ok, any}
  def fs_init(:prod) do
    with {:error, :enoent} <- File.read("#{@state_path}/.formatted") do
      format_state_part
    end
  end

  @spec fs_init(any) :: {:ok, :development}
  def fs_init(_) do
    {:ok, :development}
  end

  def init([%{target: target, compat_version: compat_version,
                      version: version, env: env}])
  do
    children = [
      supervisor(Farmbot.Supervisor, [%{target: target, compat_version: compat_version,
                          version: version, env: env}], restart: :permanent)
    ]
    opts = [strategy: :one_for_one, name: Farmbot]
    supervise(children, opts)
  end

  def start(_type, [%{target: target, compat_version: compat_version,
                      version: version, env: env}])
  do
    {:ok, _} = fs_init(env)
    Logger.debug("Starting Firmware on Target: #{target}")
    Supervisor.start_link(__MODULE__,
          [%{target: target, compat_version: compat_version,
             version: version, env: env}])
  end

  @doc """
    Formats the data partition and reboots.
  """
  @spec factory_reset :: any
  def factory_reset do
    # i don't remember why i stop SafeStorage. I wish i had documented that.
    GenServer.stop SafeStorage, :reset
    Nerves.Firmware.reboot
  end
end
