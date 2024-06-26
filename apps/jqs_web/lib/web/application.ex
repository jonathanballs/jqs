defmodule Jqs.Web.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Jqs.Web.Telemetry,
      Jqs.Web.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Jqs.Web.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    Jqs.Web.Endpoint.config_change(changed, removed)
    :ok
  end
end
