defmodule Jqs.Queues.QueueSupervisor do
  alias Jqs.Queues.Queue

  use Supervisor, restart: :permanent

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  def init({name, worker, opts}) do
    children = [
      {Queue, {name, worker, [{:queue_supervisor, self()} | opts]}}
    ]

    # We want to set a high number for the max restarts to handle the edge case
    # where the registry does not process the :DOWN message for a short time.
    Supervisor.init(children, strategy: :rest_for_one, max_restarts: 30)
  end

  def child_spec({name, _, _} = args) do
    %{
      id: name,
      start: {__MODULE__, :start_link, [args]}
    }
  end
end
