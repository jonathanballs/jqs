defmodule Jqs.Queues.Worker do
  alias Jqs.Queues.Task
  alias Jqs.Queues.Queue

  @type result :: :ok | any()
  @callback perform(task :: Task.t()) :: result()

  @spec safe_start_task(pid(), Task.t()) :: :ok | :error
  def safe_start_task(worker, %Task{} = task) do
    try do
      :ok = GenServer.call(worker, {:start_task, task}, 1000)
    catch
      _ ->
        :error
    end
  end

  defmacro __using__(_opts) do
    quote location: :keep do
      require Logger
      use GenServer

      defstruct queue: nil

      alias Jqs.Queues.{Task, Worker}
      @behaviour Worker

      @impl true
      def handle_call({:start_task, %Task{} = task}, {queue, _}, state) do
        GenServer.cast(self(), {:perform, {task, queue}})
        {:reply, :ok, state}
      end

      @impl true
      def handle_cast({:perform, {task, queue}}, state) do
        Logger.info("Starting #{task.id} (attempt #{task.attempts} of #{task.max_retries + 1})")

        # This will crash the worker process if `perform/1` does not return :ok
        # however this is expected and will be handled gracefully by the
        # `Queue` which will mark the task as failed.
        :ok = perform(task)

        Logger.info("Completed #{task.id} successfully.")

        :ok = Queue.task_complete(queue, task.id)

        {:noreply, state}
      end

      @impl true
      def init(queue_name) do
        Logger.metadata(queue_name: queue_name, worker: self())
        Logger.info("Initializing worker")
        {:ok, nil}
      end

      def start_link(queue_name) do
        GenServer.start_link(__MODULE__, queue_name)
      end
    end
  end
end
