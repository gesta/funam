defmodule Worker do
  require Logger
  require Poison
  require HTTPotion

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  def translate(pid, phrase), do: GenServer.cast(pid, {:translate, phrase, HTTPotion.get(translation_query(phrase))})

  def handle_call(:stop, _from, state), do: {:stop, :normal, :ok, state}

  def handle_cast({:translate, phrase, %HTTPotion.Response{status_code: code, body: body}}, state)
  when is_integer(code) and code >= 200 and code < 300 do
    Logger.info "worker [#{node()}-#{inspect self()}] is on the job"
    {:ok, parsed_body} = Poison.Parser.parse(body)
    translation = List.first(parsed_body["tuc"])["phrase"]["text"]
    Logger.info "'#{phrase}' translates as '#{translation}'"
    {:stop, :normal, [translation | state]}
  end

  def handle_cast({:translate, phrase, %HTTPotion.ErrorResponse{message: message}}, state) do
    {:error, :normal, [message | state]}
  end

  def handle_cast({:translate, phrase, %HTTPotion.Response{status_code: code, body: body}}, state)
  when code >= 300 do
    {:error, :normal, state}
  end

  defp translation_query(phrase) do
    "https://glosbe.com/gapi/translate?from=eng&dest=bg&format=json&phrase=#{phrase}"
  end
end
