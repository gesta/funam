defmodule Funam do
  require Logger

  use Application

  @timeout 5000

  def start(type, _args \\ []) do
    pools_config =
      [
        [name: "Pool1",
         mfa: {Worker, :start_link, []},
         size: 3,
         max_overflow: 1
        ],
        [name: "Pool2",
         mfa: {Worker, :start_link, []},
         size: 3,
         max_overflow: 0
        ],
        [name: "Pool3",
         mfa: {Worker, :start_link, []},
         size: 3,
         max_overflow: 0
        ],
      ]

    case type do
      :normal ->
        Logger.info("Application starts on #{node()}")

      {:takeover, old_node} ->
        Logger.info("#{node()} takes over #{old_node}")

      {:failover, old_node} ->
        Logger.info("#{old_node} fails over to #{node()}")
    end

    start_pools(pools_config)
  end

  def start_pools(pools_config) do
    Funam.Supervisor.start_link(pools_config)
  end

  def checkout(pool_name, block \\ true, timeout \\ @timeout) do
    Funam.Server.checkout(pool_name, block, timeout)
  end

  def checkin(pool_name, worker_pid) do
    Funam.Server.checkin(pool_name, worker_pid)
  end

  def status(pool_name) do
    Funam.Server.status(pool_name)
  end
end
