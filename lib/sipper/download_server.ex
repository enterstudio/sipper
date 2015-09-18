defmodule Sipper.DownloadServer do
  use GenServer

  # Client API

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: :downloader)
  end

  def get(path, {id, name}, auth) do
    GenServer.call(:downloader, {:get, path, {id, name}, auth}, :infinity)
  end

  def await do
    GenServer.call(:downloader, :await, :infinity)
  end

  # GenServer API

  def init(_) do
    # FIXME: named pool

    {:ok, pool} = :poolboy.start_link(
      [worker_module: Sipper.DownloadWorker, size: 5, max_overflow: 0]
    )

    {:ok, {pool, []}}
  end

  def handle_call({:get, path, {id, name}, auth}, _from, {pool, tasks}) do

    new_task = Task.async fn ->
      :poolboy.transaction pool, fn(worker_pid) ->
        Sipper.DownloadWorker.fetch(worker_pid, {path, {id, name}, auth})
      end, :infinity
    end

    {:reply, nil, {pool, [new_task|tasks]}}
  end

  def handle_call(:await, _from, {pool, tasks}) do
    tasks |> Enum.each &Task.await(&1, :infinity)

    {:reply, nil, {pool, []}}
  end
end
