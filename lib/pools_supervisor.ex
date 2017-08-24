defmodule Funam.PoolsSupervisor do
  use Supervisor

  def start_link, do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    opts = [strategy: :one_for_one]

    supervise([], opts)
  end
end
