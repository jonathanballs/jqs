defmodule Jqs.Queues.Task do
  @type priority :: :high | :low

  @default_max_retries 3
  @default_priority :low
  @default_backoff_ms 1000

  @type t :: %__MODULE__{
          id: String.t(),
          queue: String.t(),
          priority: priority(),
          context: any(),
          attempts: non_neg_integer(),
          max_retries: non_neg_integer(),
          backoff_ms: non_neg_integer()
        }

  defstruct [:id, :queue, :priority, :context, :attempts, :max_retries, :backoff_ms]

  @spec new(String.t(), any(), Keyword.t()) :: __MODULE__.t()
  def new(queue, context \\ %{}, opts \\ []) do
    %__MODULE__{
      id: "task_" <> FlakeId.get(),
      queue: queue,
      priority: Keyword.get(opts, :priority, @default_priority),
      context: context,
      attempts: 0,
      max_retries: Keyword.get(opts, :max_retries, @default_max_retries),
      backoff_ms: Keyword.get(opts, :backoff_ms, @default_backoff_ms)
    }
  end

  def increment_attempts(%__MODULE__{attempts: attempts} = task) do
    %{task | attempts: attempts + 1}
  end

  def can_retry?(%__MODULE__{attempts: attempts, max_retries: max_retries}) do
    attempts <= max_retries
  end
end
