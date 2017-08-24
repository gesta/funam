defmodule Funam.PoolsSupervisor do
  use Supervisor

  @doc """
  Start the Supervisor and name it as the module.
  """
  def start_link, do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  @doc """
  The Supervisor starts with no pools.
  If any pool fails, it should not affect the other pools.
  """
  def init(_) do
    opts = [strategy: :one_for_one]

    supervise([], opts)
  end
end
