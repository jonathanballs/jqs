defmodule Jqs.Queues do
  alias Jqs.Queues.Queue
  alias Jqs.Queues.QueueSupervisor
  alias Jqs.Queues.QueueRegistry
  alias Jqs.Queues.Task

  require Logger

  use Supervisor

  @dead_letter_queue_name "dead_letter"

  def start_link(queues) do
    Supervisor.start_link(__MODULE__, queues, name: __MODULE__)
  end

  @impl true
  def init(queues) do
    Logger.info("Starting Jqs.Queues supervisor")

    [{@dead_letter_queue_name, nil, [concurrency: 0]} | queues]
    |> Enum.map(&{QueueSupervisor, &1})
    |> Supervisor.init(strategy: :one_for_one)
  end

  @doc """
  Sends the task to the correct queue for processing.
  """
  @spec enqueue(Task.t()) :: {:ok, Task.t()} | {:error, :queue_not_found}
  def enqueue(%Task{} = task) do
    case QueueRegistry.lookup(task.queue) do
      [{queue, _}] ->
        Queue.enqueue(queue, task)

      [] ->
        {:error, :queue_not_found}
    end
  end

  def send_to_dead_letter_queue(%Task{} = task) do
    case QueueRegistry.lookup(@dead_letter_queue_name) do
      [{queue, _}] ->
        Queue.enqueue(queue, task)

      [] ->
        {:error, :queue_not_found}
    end
  end
end
