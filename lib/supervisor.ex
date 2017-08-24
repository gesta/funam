defmodule Funam.Supervisor do
  use Supervisor

  def start_link(pools_config), do: Supervisor.start_link(__MODULE__, pools_config, name: __MODULE__)

  def init(pools_config) do
    children = [
      supervisor(Funam.PoolsSupervisor, []),
      worker(Funam.Server, [pools_config])
    ]

    opts = [strategy: :one_for_all,
            max_restart: 3,
            max_time: 6000]

    supervise(children, opts)
  end
end
