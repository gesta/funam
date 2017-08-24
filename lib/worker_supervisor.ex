defmodule Funam.WorkerSupervisor do
  use Supervisor

  @doc """
  Start the Supervisor with the pid of the pool server
  and a module, function, arguments tuple.
  """
  def start_link(pool_server, {_,_,_} = mfa) do
    Supervisor.start_link(__MODULE__, [pool_server, mfa])
  end

  @doc """
  Specify that the worker is always to be restarted,
  specify the function to start the worker,
  create a list of the child processes,
  specify the options for the supervisor,
  and call a helper function to create the child specification.
  """
  def init([pool_server, {m,f,a}]) do
    Process.link(pool_server)
    worker_opts = [restart: :temporary,
                   shutdown: 5000,
                   function: f]

    children = [worker(m, a, worker_opts)]
    opts     = [strategy:    :simple_one_for_one,
                max_restart: 5,
                max_time:    3600]

    supervise(children, opts)
  end
end
