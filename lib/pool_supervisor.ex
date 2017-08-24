defmodule Funam.PoolSupervisor do
  use Supervisor

  @doc """
  Start the Supervisor with unique name.
  """
  def start_link(pool_config) do
    Supervisor.start_link(__MODULE__, pool_config, [name: :"#{pool_config[:name]}Supervisor"])
  end

  def init(pool_config) do
    opts = [strategy: :one_for_all]

    children = [worker(Funam.PoolServer, [self(), pool_config])]

    supervise(children, opts)
  end
end
