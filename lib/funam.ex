defmodule Funam do
  use Application
  require Logger
  require HTTPotion

  def start(type, _args) do
    case type do
      :normal ->
        Logger.info("Application starts on #{node()}")

      {:takeover, old_node} ->
        Logger.info("#{node()} takes over #{old_node}")

      {:failover, old_node} ->
        Logger.info("#{old_node} fails over to #{node()}")
    end

    Funam.Supervisor.start_link(:ok)
  end
end
