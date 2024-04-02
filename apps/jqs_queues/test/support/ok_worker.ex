defmodule Jqs.Queues.Workers.OkWorker do
  use Jqs.Queues.Worker

  @impl true
  def perform(_task) do
    :ok
  end
end
