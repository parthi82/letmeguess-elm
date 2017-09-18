defmodule LetmeguessWeb.RedirectController do
  use LetmeguessWeb, :controller

  def handle_redirect(conn, _params) do
    # render conn, "index.html"
    room_id = :crypto.strong_rand_bytes(7)
              |> Base.url_encode64
              |> binary_part(0, 7)
    redirect conn, to: "/#{room_id}"
  end
end
