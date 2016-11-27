defmodule Letmeguess.Router do
  use Letmeguess.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Letmeguess do
    pipe_through :browser # Use the default browser stack

    get "/", RedirectController, :handle_redirect
    get "/*path", PageController, :index

  end

  # Other scopes may use custom stacks.
  # scope "/api", Letmeguess do
  #   pipe_through :api
  # end
end
