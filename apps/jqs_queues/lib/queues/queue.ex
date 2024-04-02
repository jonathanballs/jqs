defmodule Jqs.Queues.Queue do
  @moduledoc """
  Documentation for `JQS.Queues.Queue`.
  """
  use GenServer, restart: :permanent

  alias Jqs.Queues
  alias Jqs.Queues.PriorityQueue
  alias Jqs.Queues.QueueRegistry
  alias Jqs.Queues.Task
  alias Jqs.Queues.Worker
  alias Jqs.Queues.WorkerSupervisor

  require Logger

  @default_concurrency 3

  defmodule State do
    defstruct [
      :name,
      :queue,
      :concurrency,
      :idle_workers,
      :active_workers,
      :backing_off_tasks,
      :worker_module,
      :queue_supervisor,
      :worker_supervisor
    ]

    @type t :: %__MODULE__{
            name: String.t(),
            queue: PriorityQueue.t(),
            concurrency: non_neg_integer(),
            idle_workers: List.t(),
            active_workers: Map.t(),
            backing_off_tasks: Map.t(),
            worker_module: module(),
            queue_supervisor: pid(),
            worker_supervisor: pid()
          }
  end

  #
  # Public API
  #
  def start_link({name, _, _} = queue_config) when is_binary(name) do
    # There is a rare race condition where the supervisor attempts to restart
    # the queue before the Registry has removed it from the ETS table. In the
    # case that the name is still in the registry we will wait a short time
    # (10ms) to allow the registry to process the :DOWN signal from the exited
    # queue. I have only been able to trigger this edge case artificially in
    # the Erlang observer by manually killing the Queue process but it's
    # possible that it could happen naturally...
    # See: https://github.com/elixir-lang/gen_stage/issues/10#issuecomment-206814694
    case QueueRegistry.lookup(name) do
      [_] -> :timer.sleep(10)
      _ -> nil
    end

    GenServer.start_link(__MODULE__, queue_config, name: via_tuple(name))
  end

  @spec enqueue(pid(), Task.t()) :: {:ok, Task.t()} | {:error, :invalid_priority}
  def enqueue(queue, %Task{} = task) do
    GenServer.call(queue, {:enqueue, task})
  end

  @spec task_complete(pid(), String.t()) :: :ok
  def task_complete(queue, task_id) do
    GenServer.call(queue, {:task_complete, task_id})
  end

  @impl true
  def init({name, worker_module, opts}) do
    Logger.metadata(queue_name: name)
    Logger.info("Initializing task queue")

    state = %State{
      name: name,
      worker_module: worker_module,
      queue: PriorityQueue.new(),
      concurrency: Keyword.get(opts, :concurrency, @default_concurrency),
      active_workers: %{},
      idle_workers: [],
      backing_off_tasks: %{},
      queue_supervisor: Keyword.fetch!(opts, :queue_supervisor)
    }

    Process.flag(:trap_exit, true)
    {:ok, state, {:continue, :start_worker_supervisor}}
  end

  #
  # Callbacks
  #

  # Starts (or restarts) the worker supervisor and the pool of workers. If a
  # worker pool already exists then they will be removed and the tasks in
  # progress will be marked as failed.
  @impl true
  def handle_continue(:start_worker_supervisor, state) do
    {:ok, worker_supervisor} = Supervisor.start_child(state.queue_supervisor, WorkerSupervisor)
    Process.link(worker_supervisor)
    state = %{state | worker_supervisor: worker_supervisor}

    {:noreply, state, {:continue, :replenish_worker_pool}}
  end

  # Creates new workers so that the size of the worker pool matches the
  # configured concurrency. This callback is idempotent.
  @impl true
  def handle_continue(:replenish_worker_pool, state) do
    current_worker_count = length(state.idle_workers) + map_size(state.active_workers)
    worker_deficiency = state.concurrency - current_worker_count

    idle_workers =
      Enum.reduce(1..worker_deficiency//1, state.idle_workers, fn _, acc ->
        child_spec = Supervisor.child_spec({state.worker_module, state.name}, restart: :temporary)
        {:ok, pid} = WorkerSupervisor.start_child(state.worker_supervisor, child_spec)
        true = Process.link(pid)
        [pid | acc]
      end)

    if worker_deficiency > 0 do
      Logger.info("Successfully started #{worker_deficiency} new workers")
    end

    {:noreply, %{state | idle_workers: idle_workers}, {:continue, :maybe_start_tasks}}
  end

  @impl true
  def handle_continue(:maybe_start_tasks, state) do
    {:noreply, maybe_start_tasks(state)}
  end

  @impl true
  def handle_call({:enqueue, %Task{} = task}, _from, %State{} = state) do
    with {:ok, queue} <- PriorityQueue.enqueue(state.queue, task, task.priority),
         state <- %{state | queue: queue} do
      Logger.info("#{task.id} enqueued successfully with #{task.priority} priority")
      {:reply, {:ok, task}, state, {:continue, :maybe_start_tasks}}
    else
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:task_complete, task_id}, {worker, _}, state) do
    case Map.get(state.active_workers, worker) do
      %Task{id: ^task_id} ->
        state = %{state | idle_workers: [worker | state.idle_workers]}
        state = %{state | active_workers: Map.delete(state.active_workers, worker)}

        Logger.info("#{task_id} marked as complete and worker #{inspect(worker)} is now idle")

        {:reply, :ok, state, {:continue, :maybe_start_tasks}}

      %Task{id: incorrect_task_id} ->
        Logger.error(
          "Received incorrect task_id (#{incorrect_task_id}) from worker. Killing worker"
        )

        Process.exit(worker, :kill)
        {:reply, :ok, state}

      nil ->
        Logger.error("Received :task_complete call from inactive worker #{inspect(worker)}")
        Logger.error(inspect(state))
        {:reply, :ok, state}
    end
  end

  # Useful for testing - ensures that all previous messages have been processed
  @impl true
  def handle_call(:sync, _from, state) do
    {:reply, :ok, state}
  end

  # WorkerSupervisor exit handling
  @impl true
  def handle_info({:EXIT, pid, :shutdown}, %{worker_supervisor: pid} = state) do
    Logger.info("Worker supervisor received shutdown. Queue shutting down gracefully...")
    {:stop, :shutdown, state}
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, %{worker_supervisor: pid} = state) do
    Logger.info("WorkerSupervisor #{inspect(pid)} exited: #{inspect(reason)}")

    # Mark all active tasks as failed
    state =
      Map.keys(state.active_workers)
      |> Enum.reduce(state, &handle_worker_exited(&2, &1))

    # Remove idle workers
    state = %{state | idle_workers: []}

    {:noreply, state, {:continue, :start_worker_supervisor}}
  end

  # Worker exit handling
  @impl true
  def handle_info({:EXIT, pid, :shutdown}, state) do
    Logger.info("Worker #{inspect(pid)} received :shutdown. Queue shutting down gracefully...")
    {:stop, :shutdown, state}
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, state) do
    Logger.info("Worker #{inspect(pid)} exited with '#{reason}'")
    state = handle_worker_exited(state, pid)
    {:noreply, state, {:continue, :replenish_worker_pool}}
  end

  @impl true
  def handle_info({:requeue, task_id}, %State{} = state) do
    case Map.pop(state.backing_off_tasks, task_id) do
      {nil, _} ->
        {:noreply, state}

      {task, backing_off_tasks} ->
        Logger.info("Requeuing #{task_id} at #{task.priority} priority")
        {:ok, queue} = PriorityQueue.enqueue(state.queue, task, task.priority)

        {:noreply, %{state | backing_off_tasks: backing_off_tasks, queue: queue},
         {:continue, :maybe_start_tasks}}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.info("Received unexpected message #{inspect(msg)}")
    {:noreply, state}
  end

  @spec handle_worker_exited(State.t(), pid()) :: State.t()
  defp handle_worker_exited(state, pid) do
    cond do
      # The exited worker was working on a task
      Map.has_key?(state.active_workers, pid) ->
        {task, active_workers} = Map.pop(state.active_workers, pid)

        if Task.can_retry?(task) do
          Process.send_after(self(), {:requeue, task.id}, task.backoff_ms)

          Logger.info(
            "#{task.id} from worker #{inspect(pid)} will be retried in #{task.backoff_ms}ms"
          )

          state = %{state | active_workers: active_workers}
          %{state | backing_off_tasks: Map.put(state.backing_off_tasks, task.id, task)}
        else
          Logger.info(
            "#{task.id} from worker #{inspect(pid)} will be sent to the dead letter queue"
          )

          {:ok, _} = Queues.send_to_dead_letter_queue(task)
          %{state | active_workers: active_workers}
        end

      # The exited worker is idle
      Enum.member?(state.idle_workers, pid) ->
        %{state | idle_workers: List.delete(state.idle_workers, pid)}

      # We have no record of the worker pid. In all likelyhood this means
      # that the worker supervisor crashed previously and we have already cleaned up.
      true ->
        state
    end
  end

  # Starts as many tasks in the queue as possible with available idle workers
  defp maybe_start_tasks(%{idle_workers: [worker | rest], queue: queue} = state) do
    case PriorityQueue.dequeue(queue) do
      {:error, :empty_queue} ->
        state

      {queue, task} ->
        task = Task.increment_attempts(task)

        Logger.info("Dispatching #{task.id} to #{inspect(worker)}")

        state =
          case Worker.safe_start_task(worker, task) do
            :ok ->
              active_workers = Map.put(state.active_workers, worker, task)
              state = %{state | active_workers: active_workers}
              %{state | queue: queue}

            :error ->
              # In the case that we can't start a task then we kill the guilty worker
              Process.exit(worker, :kill)
              state
          end

        %{state | idle_workers: rest}
        |> maybe_start_tasks()
    end
  end

  defp maybe_start_tasks(state) do
    state
  end

  defp via_tuple(name) do
    QueueRegistry.via_tuple(name)
  end
end
