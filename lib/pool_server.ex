defmodule Funam.PoolServer do
  use GenServer
  import Supervisor.Spec

  defmodule State do
    @moduledoc """
    Helper module, containing a struct to define
    all possible properties of a server state.
    """
    defstruct pool_sup: nil,
    worker_sup: nil,
    monitors: nil,
    monitors: nil,
    size: nil,
    workers: nil,
    name: nil,
    mfa: nil,
    waiting: nil,
    overflow: nil,
    max_overflow: nil
  end

  @doc """
  Take the pool Supervisor's pid and connect a the current process
  to a new GenServer process.
  """
  def start_link(pool_sup, pool_config) do
    GenServer.start_link(__MODULE__, [pool_sup, pool_config], name: name(pool_config[:name]))
  end

  @doc """
  Perform a sync call for a checkout to a specific server.
  """
  def checkout(pool_name, timeout) do
    GenServer.call(name(pool_name), :checkout, timeout)
  end

  @doc """
  Perform an async call for a checkin to a specific server.
  """
  def checkin(pool_name, worker_pid) do
    GenServer.cast(name(pool_name), {:checkin, worker_pid})
  end

  @doc """
  Perform a sync call for status data about specific server.
  """
  def status(pool_name) do
    GenServer.call(name(pool_name), :status)
  end

  @doc """
  Store the pool Supervisor’s pid in the GenServer’s state.
  Use helper init functions to save each and every property.
  """
  def init([pool_sup, pool_config]) when is_pid(pool_sup) do
    Process.flag(:trap_exit, true)
    monitors = :ets.new(:monitors, [:private])
    waiting  = :queue.new
    state    = %State{pool_sup: pool_sup, monitors: monitors, waiting: waiting, overflow: 0}

    init(pool_config, state)
  end

  def init([{:name, name}|rest], state) do
    init(rest,  %{state | name: name})
  end

  def init([{:mfa, mfa}|rest], state) do
    init(rest,  %{state | mfa: mfa})
  end

  def init([{:size, size}|rest], state) do
    init(rest, %{state | size: size})
  end

  def init([{:max_overflow, max_overflow}|rest], state) do
    init(rest, %{state | max_overflow: max_overflow})
  end

  @doc """
  Send a message to thyself to generate the worker Supervisor process.
  """
  def init([], state) do
    send(self, :start_worker_supervisor)
    {:ok, state}
  end

  def init([_|rest], state) do
    init(rest, state)
  end

  @doc """
  Check if the workers are overflowing the capacity of the pool.
  If a new worker is created, its information is saved in the
  'monitors' table in the ets.
  """
  def handle_call(:checkout, {from_pid, _ref} = from, state) do
    %{worker_sup:   worker_sup,
      workers:      workers,
      monitors:     monitors,
      waiting:      waiting,
      overflow:     overflow,
      max_overflow: max_overflow} = state

    case workers do
      [worker|rest] ->
        ref = Process.monitor(from_pid)
        true = :ets.insert(monitors, {worker, ref})
        {:reply, worker, %{state | workers: rest}}

      [] when max_overflow > 0 and overflow < max_overflow ->
        {worker, ref} = new_worker(worker_sup, from_pid)
        true = :ets.insert(monitors, {worker, ref})
        {:reply, worker, %{state | overflow: overflow+1}}

      [] ->
        {:reply, :full, state};
    end
  end

  @doc """
  Report wether the pool is :overflow , :full , or :ready.
  """
  def handle_call(:status, _from, %{workers: workers, monitors: monitors} = state) do
    {:reply, {state_name(state), length(workers), :ets.info(monitors, :size)}, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, {:error, :invalid_message}, :ok, state}
  end

  @doc """
  Unlink the worker from the pool server and tell the worker Supervisor
  to terminate the child.
  """
  def handle_cast({:checkin, worker}, %{monitors: monitors} = state) do
    case :ets.lookup(monitors, worker) do
      [{pid, ref}] ->
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, pid)
        new_state = handle_checkin(pid, state)
        {:noreply, new_state}

      [] ->
        {:noreply, state}
    end
  end

  @doc """
  Start a worker supervisor through the pool Supervisor
  and populate the worker Supervisor with workers.
  """
  def handle_info(:start_worker_supervisor, state = %{pool_sup: pool_sup, name: name, mfa: mfa, size: size}) do
    {:ok, worker_sup} = Supervisor.start_child(pool_sup, supervisor_spec(name, mfa))
    workers = populate(size, worker_sup)
    {:noreply, %{state | worker_sup: worker_sup, workers: workers}}
  end

  def handle_info({:DOWN, ref, _, _, _}, state = %{monitors: monitors, workers: workers}) do
    case :ets.match(monitors, {:"$1", ref}) do
      [[pid]] ->
        true = :ets.delete(monitors, pid)
        new_state = %{state | workers: [pid|workers]}
        {:noreply, new_state}

      [[]] ->
        {:noreply, state}
    end
  end

  @doc """
  When its Supervisor crashes, stop the server for the same reason.
  """
  def handle_info({:EXIT, worker_sup, reason}, state = %{worker_sup: worker_sup}) do
    {:stop, reason, state}
  end

  @doc """
  Check whether the pool is overflowed, and if so, you decrement the counter.
  """
  def handle_info({:EXIT, pid, _reason}, state = %{monitors: monitors, workers: workers, worker_sup: worker_sup}) do
    case :ets.lookup(monitors, pid) do
      [{pid, ref}] ->
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, pid)
        new_state = handle_worker_exit(pid, state)
        {:noreply, new_state}

      [] ->
        case Enum.member?(workers, pid) do
          true ->
            remaining_workers = workers |> Enum.reject(fn(p) -> p == pid end)
            new_state = %{state | workers: [new_worker(worker_sup)|remaining_workers]}
            {:noreply, new_state}

            false ->
              {:noreply, state}
        end
    end
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end

  def terminate(_reason, _state) do
    :ok
  end


  defp name(pool_name) do
    :"#{pool_name}Server"
  end

  defp populate(size, sup) do
    populate(size, sup, [])
  end

  defp populate(size, _sup, workers) when size < 1 do
    workers
  end

  defp populate(size, sup, workers) do
    populate(size-1, sup, [new_worker(sup)|workers])
  end

  defp new_worker(sup) do
    {:ok, worker} = Supervisor.start_child(sup, [[]])
    true = Process.link(worker)
    worker
  end

  defp new_worker(sup, from_pid) do
    pid = new_worker(sup)
    ref = Process.monitor(from_pid)
    {pid, ref}
  end

  @doc """
  Terminate the worker and decrement overflow.
  """
  defp dismiss_worker(sup, pid) do
    true = Process.unlink(pid)
    Supervisor.terminate_child(sup, pid)
  end

  def handle_checkin(pid, state) do
    %{worker_sup:   worker_sup,
      workers:      workers,
      monitors:     monitors,
      waiting:      waiting,
      overflow:     overflow} = state

    case :queue.out(waiting) do
      {{:value, {from, ref}}, left} ->
        true = :ets.insert(monitors, {pid, ref})
        GenServer.reply(from, pid)
        %{state | waiting: left}

        {:empty, empty} when overflow > 0 ->
        :ok = dismiss_worker(worker_sup, pid)
        %{state | waiting: empty, overflow: overflow-1}

      {:empty, empty} ->
        %{state | waiting: empty, workers: [pid|workers], overflow: 0}
    end
  end

  defp handle_worker_exit(pid, state) do
    %{worker_sup:   worker_sup,
      workers:      workers,
      monitors:     monitors,
      waiting:      waiting,
      overflow:     overflow} = state

    case :queue.out(waiting) do
      {{:value, {from, ref}}, left} ->
        new_worker = new_worker(worker_sup)
        true = :ets.insert(monitors, {new_worker, ref})
        GenServer.reply(from, new_worker)
        %{state | waiting: left}

      {:empty, empty} when overflow > 0 ->
        %{state | overflow: overflow-1, waiting: empty}

      {:empty, empty} ->
        workers = [new_worker(worker_sup) | workers |> Enum.reject(fn(p) -> p != pid end)]
        %{state | workers: workers, waiting: empty}
    end
  end

  @doc """
  Get specification of the children for the worker Supervisor.
  """
  defp supervisor_spec(name, mfa) do
    opts = [id: name <> "WorkerSupervisor", shutdown: 10000, restart: :temporary]
    supervisor(Funam.WorkerSupervisor, [self, mfa], opts)
  end

  defp state_name(%State{overflow: overflow, max_overflow: max_overflow, workers: workers}) when overflow < 1 do
    case length(workers) == 0 do
      true ->
        if max_overflow < 1 do
          :full
        else
          :overflow
        end
      false ->
        :ready
    end
  end

  defp state_name(%State{overflow: max_overflow, max_overflow: max_overflow}) do
    :full
  end

  defp state_name(_state) do
    :overflow
  end
end
