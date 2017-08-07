defmodule Funam.Worker do
  require Logger
  require Poison

  def start(url) do
    handle_response(HTTPotion.get(url))
  end

  defp handle_response(%HTTPotion.Response{status_code: code, body: body})
  when code >= 200 and code <= 304 do
    Logger.info "worker [#{node}-#{inspect self}] completed"
    {:ok, parsed_body} = Poison.Parser.parse(body)
    {:ok, List.first(parsed_body["tuc"])["phrase"]["text"]}
  end

  defp handle_response({:error, reason}) do
    Logger.info "worker [#{node}-#{inspect self}] error due to #{inspect reason}"
    {:error, reason}
  end
end
