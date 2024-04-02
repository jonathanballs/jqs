defmodule Jqs.Web.TaskJSON do
  alias Jqs.Queues.Task

  @doc """
  Renders a single task.
  """
  def show(%{task: task}) do
    %{data: data(task)}
  end

  defp data(%Task{} = task) do
    %{
      id: task.id,
      priority: task.priority,
      context: task.context,
      max_retries: task.max_retries,
      backoff_ms: task.backoff_ms,
      queue: task.queue
    }
  end
end
