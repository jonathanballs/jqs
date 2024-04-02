defmodule Jqs.Queues.QueueRegistry do
  def start_link do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  def via_tuple(queue_name) do
    {:via, Registry, {__MODULE__, queue_name}}
  end

  def lookup(queue_name) do
    Registry.lookup(__MODULE__, queue_name)
  end

  def child_spec(_) do
    Supervisor.child_spec(
      Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end
end
