defmodule Jqs.Queues.PriorityQueue do
  @moduledoc """
  The PriorityQueue module implements a basic generic priority queue with two
    levels of priority (:high and :low) based on Erlangs :queue module. It
    supports enqueueing, dequeueing and checking queue length.
  """

  defstruct high_priority: :queue.new(), low_priority: :queue.new()

  @type priority :: :high | :low

  @doc """
  Creates a new empty PriorityQueue
  """
  @spec new() :: PriorityQueue.t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Adds a new item to the PriorityQueue.
  """
  @spec enqueue(PriorityQueue.t(), any(), priority()) ::
          {:ok, PriorityQueue.t()}
          | {:error, :invalid_priority}
  def enqueue(%__MODULE__{low_priority: q} = priority_queue, task, :low) do
    {:ok, %{priority_queue | low_priority: :queue.in(task, q)}}
  end

  def enqueue(%__MODULE__{high_priority: q} = priority_queue, task, :high) do
    {:ok, %{priority_queue | high_priority: :queue.in(task, q)}}
  end

  def enqueue(%__MODULE__{}, _task, _invalid_priority) do
    {:error, :invalid_priority}
  end

  @doc """
  Removes the highest priority item in the PriorityQueue
  """
  @spec dequeue(PriorityQueue.t()) :: {PriorityQueue.t(), any()} | {:error, :empty_queue}
  def dequeue(%__MODULE__{high_priority: h_q, low_priority: l_q} = priority_queue) do
    cond do
      not :queue.is_empty(h_q) ->
        {{:value, task}, h_q} = :queue.out(h_q)
        {%{priority_queue | high_priority: h_q}, task}

      not :queue.is_empty(l_q) ->
        {{:value, task}, l_q} = :queue.out(l_q)
        {%{priority_queue | low_priority: l_q}, task}

      true ->
        {:error, :empty_queue}
    end
  end

  @doc """
  Returns the length of the PriorityQueue
  """

  @spec length(PriorityQueue.t()) :: non_neg_integer()
  def(length(%__MODULE__{high_priority: h_q, low_priority: l_q})) do
    :queue.len(h_q) + :queue.len(l_q)
  end
end
