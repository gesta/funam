defmodule Funam.Server do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], [name: {:global, __MODULE__}])
  end

  def translate(phrase) do
    GenServer.call({:global, __MODULE__}, {:translate, phrase})
  end


  def init([]) do
    {:ok, []}
  end

  def handle_call({:translate, phrase}, _from, _wut) do
    {:reply, translation_query(phrase), []}
  end

  def translation_query(phrase) do
    "https://glosbe.com/gapi/translate?from=eng&dest=bg&format=json&phrase=#{phrase}"
  end
end
