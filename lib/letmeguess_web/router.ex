defmodule LetmeguessWeb.Router do
  use LetmeguessWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", LetmeguessWeb do
    # Use the default browser stack
    pipe_through(:browser)

    get("/", RedirectController, :handle_redirect)
    get("/*path", PageController, :index)
  end

  # Other scopes may use custom stacks.
  # scope "/api", Letmeguess do
  #   pipe_through :api
  # end
end
