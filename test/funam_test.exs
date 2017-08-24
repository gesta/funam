defmodule FunamTest do
  use ExUnit.Case

  test "handles correct response" do
    {:ok, body} = Poison.encode(%{"tuc" => [%{"phrase" => %{"text" => "дума"}}]})
    response = %HTTPotion.Response{status_code: 200, body: body}
    assert Worker.handle_cast({:translate, "word", response}, []) == {:stop, :normal, ["дума"]}
  end

  test "handles error response" do
    response = %HTTPotion.ErrorResponse{message: "An error's been raised"}
    assert Worker.handle_cast({:translate, "word", response}, []) == {:error, :normal, ["An error's been raised"]}
  end

  test "handles status code for error" do
    response = %HTTPotion.Response{status_code: 500, body: <<>>}
    assert Worker.handle_cast({:translate, "word", response}, []) == {:error, :normal, []}
  end
end
