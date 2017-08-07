defmodule Funam.Server do
  require Logger

  def do_it(phrase) do
    Funam.Server.start_link()
    Funam.Server.translate(phrase)
  end

  def translate_phrase(url, nodes \\ Node.list()) do
    Funam.Worker.start(translation_query(url))
  end

  defp do_help do
    IO.puts "Summat went wrong"
  end

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
    {:reply, translate_phrase(phrase), []}
  end

  def translation_query(phrase) do
    "https://glosbe.com/gapi/translate?from=eng&dest=bg&format=json&phrase=#{phrase}"
  end
end
