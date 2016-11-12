defmodule Etimer do
  use GenServer

  alias Etimer.Timer

  defstruct running: []

  # API
  def start_link(server_name) do
    GenServer.start_link(__MODULE__, server_name)
  end

  @spec stop(term) :: :ok
  def stop(server_name) do
    call(server_name, :stop)
  end

  @type cb :: {module, atom, term}
  @spec start_timer(term, term, non_neg_integer, cb) :: :ok
  def start_timer(server_name, tname, timeout, cb) when is_integer(timeout) and timeout >= 0 do
    call(server_name, {:start_timer, tname, timeout, cb})
  end

  @spec stop_timer(term, term) :: :not_running | {:ok, non_neg_integer}
  def stop_timer(server_name, tname) do
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
  @callback handle_call({:start_timer, term, non_neg_integer, cb}, pid, %Etimer{running: list(tuple)}) ::
    {:reply, :ok, %Etimer{running: list(tuple)}}
  def handle_call({:start_timer, tname, timeout, cb={_m, _f, _a}}, _from, state) do
    # If the tname timer is running we clean it up.
    # Otherwise just start it.

    timers = case List.keytake(state.running, tname, 0) do
      nil ->
        state.running
      {{_k, tref}, newts} ->
         Timer.cancel_timer(tref)
        newts
    end

    trefnew = Timer.start_timer(timeout, self, {tname, cb})

    {:reply, :ok, %Etimer{
      running: [{tname, trefnew}] ++ timers
      }
    }
  end

  @doc false
  @callback handle_call({:stop_timer, term}, pid, %Etimer{running: list(tuple)}) ::
    {:reply, :not_running, %Etimer{running: list(tuple)}} |
    {:reply, {:ok, non_neg_integer}, %Etimer{running: list(tuple)}}
  def handle_call({:stop_timer, tname}, _from, state) do
    case List.keytake(state.running, tname, 0) do
      nil ->
        {:reply, :not_running, state}
      {{_k, tref}, newts} ->
        time_left = Timer.cancel_timer(tref)
        {:reply, {:ok, time_left}, %Etimer{running: newts}}
    end
  end

  @doc false
  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  @doc false
  def handle_cast(_any, state) do
    {:noreply, state}
  end

  @doc false
  @callback handle_info({:timeout, reference, {term, cb}}, %Etimer{running: list(tuple)}) ::
    {:noreply, %Etimer{running: list(tuple)}}
  def handle_info({:timeout, tref, {tname, {mod, fun, args}}}, state) do

    timers = case List.keytake(state.running, tname, 0) do
      nil ->
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

  @doc false
  def terminate(_reason, state) do
    # stop all timers
    state.running
    |> Enum.each(fn(tref) ->
      _ = Timer.cancel_timer(tref)
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
