defmodule Jqs.Queues.PriorityQueuesTest do
  use ExUnit.Case

  alias Jqs.Queues.PriorityQueue

  test "Dequeueing of same priority level is FIFO" do
    pq = PriorityQueue.new()
    {:ok, pq} = PriorityQueue.enqueue(pq, :first, :low)
    {:ok, pq} = PriorityQueue.enqueue(pq, :second, :low)

    {pq, :first} = PriorityQueue.dequeue(pq)
    {pq, :second} = PriorityQueue.dequeue(pq)

    assert PriorityQueue.length(pq) == 0
  end

  test "High priority items are dequeued first" do
    pq = PriorityQueue.new()
    {:ok, pq} = PriorityQueue.enqueue(pq, :first, :low)
    {:ok, pq} = PriorityQueue.enqueue(pq, :second, :high)

    {pq, :second} = PriorityQueue.dequeue(pq)
    {pq, :first} = PriorityQueue.dequeue(pq)

    assert PriorityQueue.length(pq) == 0
  end

  test "enqueue/3 returns error with invalid priority" do
    pq = PriorityQueue.new()
    {:error, :invalid_priority} = PriorityQueue.enqueue(pq, :item, :example_invalid_priority)
    {:error, :invalid_priority} = PriorityQueue.enqueue(pq, :item, nil)
  end

  test "dequeue/1 returns error when queue is empty" do
    pq = PriorityQueue.new()
    {:error, :empty_queue} = PriorityQueue.dequeue(pq)
  end

  test "length/1 returns combined length of both priorities" do
    pq = PriorityQueue.new()
    assert PriorityQueue.length(pq) == 0

    {:ok, pq} = PriorityQueue.enqueue(pq, :first, :low)
    assert PriorityQueue.length(pq) == 1

    {:ok, pq} = PriorityQueue.enqueue(pq, :second, :low)
    assert PriorityQueue.length(pq) == 2

    {:ok, pq} = PriorityQueue.enqueue(pq, :third, :high)
    assert PriorityQueue.length(pq) == 3

    {pq, :third} = PriorityQueue.dequeue(pq)
    {pq, :first} = PriorityQueue.dequeue(pq)
    {pq, :second} = PriorityQueue.dequeue(pq)
    assert PriorityQueue.length(pq) == 0
  end
end
