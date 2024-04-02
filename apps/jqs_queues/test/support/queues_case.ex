defmodule Jqs.Queues.QueuesCase do
  alias Jqs.Queues.QueueSupervisor
  alias Jqs.Queues.Workers.OkWorker
  use ExUnit.CaseTemplate

  using do
    quote do
      import Jqs.Queues.QueuesCase

      setup config do
        worker_module = Map.get(config, :worker_module, OkWorker)
        concurrency = Map.get(config, :concurrency, 3)

        queue_name = Atom.to_string(config.test)
        child_spec = {QueueSupervisor, {queue_name, worker_module, [concurrency: concurrency]}}

        queue_supervisor = start_supervised!(child_spec)
        [{queue, _}] = Jqs.Queues.QueueRegistry.lookup(queue_name)

        GenServer.call(queue, :sync)

        {_, worker_supervisor, _, _} =
          Supervisor.which_children(queue_supervisor)
          |> Enum.filter(&match?({Jqs.Queues.WorkerSupervisor, _pid, :supervisor, _spec}, &1))
          |> hd()

        workers =
          Supervisor.which_children(worker_supervisor)
          |> Enum.map(fn {_, pid, :worker, _} -> pid end)

        %{
          queue: queue,
          queue_supervisor: queue_supervisor,
          worker_supervisor: worker_supervisor,
          workers: workers,
          concurrency: concurrency,
          worker_module: worker_module
        }
      end
    end
  end
end
