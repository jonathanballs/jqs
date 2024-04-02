defmodule Jqs.Queues.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @queues Application.compile_env!(:jqs_queues, :queues)

  @impl true
  def start(_type, _args) do
    children = [
      Jqs.Queues.QueueRegistry,
      {Jqs.Queues, @queues}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
