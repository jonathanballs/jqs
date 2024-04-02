defmodule Jqs.Web.TaskControllerTest do
  use Jqs.Web.ConnCase, async: true

  test "Errors if queue does not exist" do
    body =
      build_conn()
      |> post("/api/tasks", %{queue: "invalid_queue"})
      |> json_response(400)

    %{"errors" => %{"detail" => "queue does not exist"}} = body
  end

  test "Renders errors if body is invalid" do
    body =
      build_conn()
      |> post("/api/tasks", %{})
      |> json_response(400)

    %{"errors" => %{"queue" => ["can't be blank"]}} = body
  end

  test "Adds a job to the queue" do
    body =
      build_conn()
      |> post("/api/tasks", %{queue: "dead_letter"})
      |> json_response(201)

    assert %{
             "data" => %{
               "id" => "task_" <> _,
               "backoff_ms" => 1000,
               "context" => %{},
               "max_retries" => 3,
               "priority" => "low"
             }
           } = body
  end
end
