defmodule LetmeguessWeb.PageControllerTest do
  use LetmeguessWeb.ConnCase

  test "GET /*", %{conn: conn} do
    conn = get conn, "/*"
    assert html_response(conn, 200) =~ "Letmeguess!"
  end
end
