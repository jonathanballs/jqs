defmodule Jqs.Queues.QueueTest do
  alias Jqs.Queues.PriorityQueue
  alias Jqs.Queues.Queue
  alias Jqs.Queues.Task
  alias Jqs.Queues.Workers.PingWorker

  use Jqs.Queues.QueuesCase

  doctest Jqs.Queues
  require Logger

  describe "init/1" do
    test "sets concurrency, queue name and worker module from arguments" do
      {:ok, state, _} =
        Queue.init(
          {"queue_name", :test_worker_module,
           concurrency: 200, queue_supervisor: :test_queue_supervisor}
        )

      assert %{
               name: "queue_name",
               concurrency: 200,
               queue_supervisor: :test_queue_supervisor,
               worker_module: :test_worker_module
             } = state
    end

    test "sets default concurrency" do
      {:ok, %{concurrency: 3}, _} =
        Queue.init({"queue_name", :test_worker_module, queue_supervisor: :test_queue_supervisor})
    end
  end

  describe "enqueue/2" do
    @tag worker_module: PingWorker
    test "starts tasks immediately", %{queue: queue} do
      task = Task.new("queue", %{pid: self()})
      Queue.enqueue(queue, task)
      task = %{task | attempts: 1}
      assert_receive(^task)
    end

    @tag worker_module: PingWorker, concurrency: 0
    test "does not start task if lacks idle workers", %{queue: queue} do
      task = Task.new("queue", %{pid: self()})
      Queue.enqueue(queue, task)
      task_id = task.id
      refute_received(^task_id)
    end

    @tag concurrency: 0
    test "returns error if priority is wrong", %{queue: queue} do
      task = %{Task.new("queue", %{pid: self()}) | priority: :invalid}
      {:error, :invalid_priority} = Queue.enqueue(queue, task)
    end
  end

  describe "handle_call/2 :enqueue" do
    test "places task into state queue" do
      task = create_task()
      state = %Queue.State{queue: PriorityQueue.new()}
      {:reply, {:ok, ^task}, state, _} = Queue.handle_call({:enqueue, task}, nil, state)

      {_, ^task} = PriorityQueue.dequeue(state.queue)
    end

    test "returns an error when priority is incorrect" do
      task = Task.new("queue_name", %{}, priority: :invalid)
      state = %Queue.State{queue: PriorityQueue.new()}

      {:reply, {:error, :invalid_priority}, state} =
        Queue.handle_call({:enqueue, task}, nil, state)

      {:error, :empty_queue} = PriorityQueue.dequeue(state.queue)
    end
  end

  describe "handle_worker/2 :task_complete" do
    test "removes task from active tasks" do
      task = create_task()

      {:reply, :ok, state, {:continue, :maybe_start_tasks}} =
        Queue.handle_call(
          {:task_complete, task.id},
          {:worker_pid, :_},
          %{
            idle_workers: [],
            active_workers: %{worker_pid: task}
          }
        )

      %{active_workers: %{}, idle_workers: [:worker_pid]} = state
    end
  end

  describe "task starting" do
    @tag worker_module: PingWorker
    @tag capture_log: true
    test "increments the task attempts on successive attempts", %{queue: queue} do
      task = Task.new("queue", %{pid: self(), crash_n_times: 2}, backoff_ms: 5)
      Queue.enqueue(queue, task)
      task = %{task | attempts: 3}
      assert_receive(^task, 1000)
    end
  end

  describe "handle_info/2 :EXIT" do
    test ":EXIT :shutdown from worker supervisor stops the queue" do
      {:stop, :shutdown, _state} =
        Queue.handle_info({:EXIT, :pid, :shutdown}, %{
          worker_supervisor: :pid
        })
    end

    test ":EXIT from worker supervisor retries all active tasks" do
      task = create_task()

      {:noreply, state, {:continue, :start_worker_supervisor}} =
        Queue.handle_info({:EXIT, :pid, :kill}, %{
          worker_supervisor: :pid,
          queue: PriorityQueue.new(),
          backing_off_tasks: %{},
          active_workers: %{pid: task},
          idle_workers: []
        })

      # No workers are active
      assert %{} = state.active_workers

      assert {:error, :empty_queue} = PriorityQueue.dequeue(state.queue)
      assert Map.has_key?(state.backing_off_tasks, task.id)
    end

    test ":EXIT, :shutdown from worker stops the queue" do
      {:stop, :shutdown, _state} =
        Queue.handle_info({:EXIT, :worker_pid, :shutdown}, %{
          worker_supervisor: :sup_pid
        })
    end

    test ":EXIT from worker retries active task" do
      task = create_task()

      {:noreply, state, {:continue, :replenish_worker_pool}} =
        Queue.handle_info({:EXIT, :worker_pid, :kill}, %{
          worker_supervisor: :sup_pid,
          queue: PriorityQueue.new(),
          idle_workers: [],
          active_workers: %{worker_pid: task},
          backing_off_tasks: %{}
        })

      # No workers are active
      %{} = state.active_workers
      [] = state.idle_workers

      # Task is back in the queue
      assert {:error, :empty_queue} = PriorityQueue.dequeue(state.queue)
      assert Map.has_key?(state.backing_off_tasks, task.id)
    end
  end

  describe "resiliency" do
    @tag worker_module: PingWorker
    test "WorkerSupervisor is restarted if killed", %{
      queue: queue,
      queue_supervisor: queue_supervisor,
      worker_supervisor: worker_supervisor
    } do
      %{active: 2} = Supervisor.count_children(queue_supervisor)
      Process.exit(worker_supervisor, :kill)
      :timer.sleep(100)

      %{active: 2} =
        Supervisor.count_children(queue_supervisor)

      {_, new_worker_supervisor, _, _} =
        Supervisor.which_children(queue_supervisor)
        |> Enum.filter(&match?({Jqs.Queues.WorkerSupervisor, _pid, :supervisor, _spec}, &1))
        |> hd()

      refute new_worker_supervisor == worker_supervisor
      refute :erlang.is_process_alive(worker_supervisor)
      assert :erlang.is_process_alive(new_worker_supervisor)

      # Assert we can still start tasks
      task = Task.new("queue", %{pid: self()})
      Queue.enqueue(queue, task)
      task = %{task | attempts: 1}
      assert_receive(^task)
    end

    @tag concurrency: 20, worker_module: PingWorker
    test "Worker is restarted if killed", %{
      worker_supervisor: worker_supervisor,
      workers: workers,
      concurrency: concurrency,
      queue: queue
    } do
      %{active: ^concurrency} = Supervisor.count_children(worker_supervisor)

      Enum.each(workers, &Process.exit(&1, :kill))
      :timer.sleep(50)

      %{active: ^concurrency} =
        Supervisor.count_children(worker_supervisor)

      # Assert we can still start tasks
      task = Task.new("queue", %{pid: self()})
      Queue.enqueue(queue, task)
      task = %{task | attempts: 1}
      assert_receive(^task)
    end
  end

  defp create_task() do
    Task.new("queue_name")
  end
end
