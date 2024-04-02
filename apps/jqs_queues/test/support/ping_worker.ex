# A simple worker that will send its task ID to the pid in its context
defmodule Jqs.Queues.Workers.PingWorker do
  use Jqs.Queues.Worker
  @impl true
  def perform(%{context: %{pid: pid} = context, attempts: attempts} = task) do
    if Map.get(context, :crash_n_times, 0) + 1 > attempts do
      raise "oops"
    end

    send(pid, task)

    :ok
  end
end
