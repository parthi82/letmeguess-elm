defmodule LetmeguessWeb.RedirectControllerTest do
  use LetmeguessWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert redirected_to(conn, 302) =~ ~r/^\/.*$/
  end
end
