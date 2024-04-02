defmodule Jqs.Web.Validators.TaskCreateTest do
  use ExUnit.Case
  alias Jqs.Web.Validators.TaskCreate

  test "throws error when queue not present" do
    {:error, changeset} = TaskCreate.validate_params(%{})
    [queue: {"can't be blank", _}] = changeset.errors
  end

  test "leaves context unchanged" do
    {:ok, task_create} = TaskCreate.validate_params(%{"queue" => "q", "context" => %{"a" => "b"}})
    %{"a" => "b"} = task_create.context
  end

  test "validates options" do
    body = %{
      "queue" => "q",
      "options" => %{
        "max_retries" => "invalid"
      }
    }

    {:error, changeset} = TaskCreate.validate_params(body)
    [max_retries: {"is invalid", _}] = changeset.changes.options.errors

    body = %{
      "queue" => "q",
      "options" => %{
        backoff_ms: -2
      }
    }

    {:error, changeset} = TaskCreate.validate_params(body)
    [backoff_ms: {"must be greater than or equal to" <> _, _}] = changeset.changes.options.errors
  end

  test "casts priority to an atom" do
    body = %{
      "queue" => "q",
      "options" => %{
        "priority" => "high"
      }
    }

    {:ok, %{options: %{priority: :high}}} = TaskCreate.validate_params(body)

    body = %{
      "queue" => "q",
      "options" => %{
        "priority" => "invalid"
      }
    }

    {:error, _changeset} = TaskCreate.validate_params(body)
  end
end
