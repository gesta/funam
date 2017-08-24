defmodule Funam.Server do
  use GenServer
  import Supervisor.Spec
  require Logger


  def start_link(pools_config) do
    GenServer.start_link(__MODULE__, pools_config, name: __MODULE__)
  end

  def checkout(pool_name, block, timeout) do
    Funam.PoolServer.checkout(pool_name, block, timeout)
  end

  def checkin(pool_name, worker_pid) do
    Funam.PoolServer.checkin(pool_name, worker_pid)
  end

  def status(pool_name) do
    Funam.PoolServer.status(pool_name)
  end

 def translate(phrase) do
   GenServer.call({:global, __MODULE__}, {:translate, phrase})
 end


  def init([]) do
    {:ok, []}
  end

  def handle_call({:translate, phrase}, _from, _wut) do
    {:reply, translate_phrase(phrase), []}
  end

  def translation_query(phrase) do
    "https://glosbe.com/gapi/translate?from=eng&dest=bg&format=json&phrase=#{phrase}"
  end
end
