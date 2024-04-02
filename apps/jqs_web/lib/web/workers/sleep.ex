alias Jqs.Queues.Worker
alias Jqs.Queues.Task

defmodule Jqs.Web.Workers.Sleep do
  use Worker

  @default_timeout 5000

  @impl true
  def perform(%Task{context: context} = _task) do
    timeout = Map.get(context, "timeout", @default_timeout)
    :timer.sleep(timeout)
    Logger.info("Slept for #{timeout}ms")

    :ok
  end
end
