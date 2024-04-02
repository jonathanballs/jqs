defmodule Jqs.Web.TaskController do
  use Jqs.Web, :controller

  alias Jqs.Queues
  alias Jqs.Queues.Task
  alias Jqs.Web.Validators.TaskCreate

  action_fallback Jqs.Web.FallbackController

  def create(conn, body) do
    with {:ok, task_create} <- TaskCreate.validate_params(body),
         opts <- options_to_keyword_list(task_create.options),
         task <- Task.new(task_create.queue, task_create.context, opts),
         {:ok, task} <- Queues.enqueue(task) do
      conn
      |> put_status(:created)
      |> render(:show, task: task)
    end
  end

  # Task creation options are sent as a JSON dictionary but we need them as a
  # keyword list. We filter out nil options as well.
  @spec options_to_keyword_list(Map.t()) :: Keyword.t()
  defp options_to_keyword_list(nil), do: []

  defp options_to_keyword_list(options) do
    options
    |> Map.from_struct()
    |> Enum.filter(fn {_, v} -> v != nil end)
    |> Enum.into([])
  end
end
