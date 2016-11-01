defmodule Letmeguess.PageController do
  use Letmeguess.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
