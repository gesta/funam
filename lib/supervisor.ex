defmodule Funam.Supervisor do
  use Supervisor

  def start_link(:ok), do: Supervisor.start_link(__MODULE__, :ok)

  def init(:ok) do
    children = [supervisor(Task.Supervisor, [[name: Funam.Server]])]

    supervise(children, [strategy: :one_for_one])
  end
end
