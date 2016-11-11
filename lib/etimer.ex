defmodule Etimer do
  use GenServer

  defstruct running: []

  # API
  def start_link(server_name) do
    GenServer.start_link(__MODULE__, server_name)
  end

  def stop(server_name) do
    call(server_name, :stop)
  end

  def start_timer(server_name, tname, timeout, cb) when is_atom(tname) and is_integer(timeout) do
    call(server_name, {:start_timer, tname, timeout, cb})
  end

  def stop_timer(server_name, tname) when is_atom(tname) do
    call(server_name, {:stop_timer, tname})
  end

  # GenServer callback
  @doc false
  def init(server_name) do
    :gproc
    server_name
    |> proc_name
    |> :gproc.reg

    {:ok, %Etimer{}}
  end

  @doc false
  def handle_call({:start_timer, tname, timeout, cb}, _from, state) do
    # If the tname timer is running we clean it up.
    # Otherwise just start it.

    timers = case List.keytake(state.running, tname, 0) do
      false ->
        state.running
      {{_k, tref}, newts} ->
         :erlang.cancel_timer(tref)
        newts
    end

    trefnew = :erlang.start_timer(timeout, self, {tname, cb})

    {:reply, :ok, %Etimer{
      running: [{tname, trefnew}] ++ timers
      }
    }
  end

  def handle_call({:stop_timer, tname}, _from, state) do

    case List.keytake(state.running, tname, 0) do
      false ->
        {:reply, :not_running, state}
      {{_k, tref}, newts} ->
        time_left = :erlang.cancel_timer(tref)
        {:reply, {:ok, time_left}, %Etimer{running: newts}}
    end

  end

  def handle_info({:timeout, tref, {tname, {mod, fun, args}}}, state) do

    timers = case List.keytake(state.running, tname, 0) do
      false ->
        state.running
      {{_k, ^tref}, newts} ->
        spawn fn ->
          apply(mod, fun, args)
        end
        newts
      {{_k, _tref}, newts} ->
        # ignored since tref is not the current one
        newts
    end

    {:noreply, %Etimer{running: timers}}
  end

  def terminate(_reason, state) do
    # stop all timers
    state.running
    |> Enum.each(fn(tref) ->
      _ = :erlang.cancel_timer(tref)
    end)
    :ok
  end

  @doc false
  defp proc_name(server_name) do
    {:n, :l, server_name}
  end

  @doc false
  defp call(server_name, msg) do
    {pid, _} = :gproc.await(proc_name(server_name))
    GenServer.call(pid, msg)
  end
end
