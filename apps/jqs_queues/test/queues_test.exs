alias Jqs.Queues.Task
alias Jqs.Queues

defmodule Jqs.QueuesTest do
  use ExUnit.Case
  doctest Jqs.Queues

  test "returns queue_not_found error when queue doesn't exist" do
    {:error, :queue_not_found} = Queues.enqueue(Task.new("invalid_queue_name"))
  end
end
