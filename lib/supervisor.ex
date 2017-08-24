defmodule Funam.Supervisor do
  use Supervisor

  @moduledoc """
  Top-level Supervisor, starting Funam.Server and Funam.PoolsSupervisor.
  """

  @doc """
  Funam.Supervisor starts as a named process.
  """
  def start_link(pools_config), do: Supervisor.start_link(__MODULE__, pools_config, name: __MODULE__)

  @doc """
  Funam.Supervisor starts with two children -
  Funam.PoolsSupervisor and a Funam.Server.
  """
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
