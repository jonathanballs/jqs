defmodule Jqs.Web.Router do
  use Jqs.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", Jqs.Web do
    pipe_through :api

    resources "/tasks", TaskController, only: [:create]
  end
end
