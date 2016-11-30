defmodule Letmeguess.RedirectControllerTest do
  use Letmeguess.ConnCase

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert redirected_to(conn, 302) =~ ~r/^\/.*$/
  end
end
