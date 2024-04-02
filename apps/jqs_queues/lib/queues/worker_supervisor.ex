defmodule Jqs.Queues.WorkerSupervisor do
  use DynamicSupervisor, restart: :temporary

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg)
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  defdelegate start_child(supervisor, spec), to: DynamicSupervisor
end
