defmodule Funam.Server do
  use GenServer
  import Supervisor.Spec
  require Logger


  def start_link(pools_config) do
    GenServer.start_link(__MODULE__, pools_config, name: __MODULE__)
  end

  def checkout(pool_name, timeout) do
    Funam.PoolServer.checkout(pool_name, timeout)
  end

  def checkin(pool_name, worker_pid) do
    Funam.PoolServer.checkin(pool_name, worker_pid)
  end

  def status(pool_name) do
    Funam.PoolServer.status(pool_name)
  end


 def init(pools_config) do
   pools_config |> Enum.each(fn(pool_config) ->
     send(self(), {:start_pool, pool_config})
   end)
   {:ok, pools_config}
 end

 def handle_info({:start_pool, pool_config}, state) do
   {:ok, _pool_sup} = Supervisor.start_child(Funam.PoolsSupervisor, supervisor_spec(pool_config))
   {:noreply, state}
 end

  defp supervisor_spec(pool_config) do
    opts = [id: :"#{pool_config[:name]}Supervisor"]
    supervisor(Funam.PoolSupervisor, [pool_config], opts)
  end
end
