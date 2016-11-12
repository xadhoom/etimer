defmodule Etimer do
  @moduledoc """
  A timer module to book keep several timers and makes it easy to abstract
  them out of tests.

  Derived (basically a porting from erlang to elixir) from
  [:chronos](https://github.com/lehoff/chronos).

  Many concepts are cleary expressed into the original package,
  which can be referenced for more details.

## Testing with Etimer (adapted from :chronos)

Provide a `timer_expiry` function as part of the API for the component
you are creating, for example:

      def timer_expiry(timer_name) do
        GenServer.call(__MODULE__, {:timer_expiry, timer_name})
      end

In the code you can request a timer like this:

      Etimer:start_timer(:my_server, :timer1, {MyMod, timer_expiry, [:timer1]})

and then handling the timeout becomes very simple:

      def handle_call({timer_expiry, :timer1}, _from, state) do
        # your timed code here
        {:reply, :something, state}
      end

That is the basic set-up and while testing you have to mock
Etimer. For example, using `:meck`:

      :meck.new(Etimer)
      :meck.expect(Etimer, :start_timer, fn(_, _, _) -> 42 end)

As part of the test you check that the timer was requsted to start:

      assert :meck.called(Etimer, :start_timer, [:my_server, :timer1])

And when you come to the point in the test where you want to see the
effects of the timer expiry you simply have to call:

      MyMod.timer_expiry(:timer1)

  """
  use GenServer

  alias Etimer.Timer

  defstruct running: []

  @doc """
  Starts a new timer server and links to the current process.

  Server name can be any `term()` which gets registered through `:gproc`.

  If the current process dies, all registered timers will be cancelled.


      Etimer.start_link(:my_server)
  """
  def start_link(server_name) do
    GenServer.start_link(__MODULE__, server_name)
  end

  @doc """
  Stops the given timer server. All outstanding timers will be cancelled.

  ## Example:

      Etimer.stop(:my_server)
  """
  @spec stop(term) :: :ok
  def stop(server_name) do
    call(server_name, :stop)
  end

  @doc """
  Starts a new timer with name `tname` on timer server `server_name`,
  with timeout `timeout`, expressed in milliseconds. After the given timeout,
  the given `cb` will be called.

  `cb` is a 3-items tuple `{module, atom, [term[]]}`,
  where `atom` is the function that will get called on module `module`,
  passings arguments expressed in `[term[]]`.

  The `cb` will get called on a separate process via `spawn`
  in order to not block the timer server.

  ## Example:

      Etimer.start_timer(:my_server, :timer1, 1_000, {IO, :inspect, ["hello"]})
  """
  @type cb :: {module, atom, term}
  @spec start_timer(term, term, non_neg_integer, cb) :: :ok
  def start_timer(server_name, tname, timeout, cb) when is_integer(timeout) and timeout >= 0 do
    call(server_name, {:start_timer, tname, timeout, cb})
  end

  @doc """
  Stops the timer with name `tname` on server `server_name`.

  ## Example:

      Etimer.stop_timer(:my_server, :timer1)

  It returns the atom `:not_running` is the timer is not running, otherwise
  the 2-element tuple `{:ok, remaing_time}`, where `remaing_time`
  is the time left before the expiry of the timer.
  The callback will not be called.
  """
  @spec stop_timer(term, term) :: :not_running | {:ok, non_neg_integer}
  def stop_timer(server_name, tname) do
    call(server_name, {:stop_timer, tname})
  end

  #
  # GenServer callbacks
  #
  @doc false
  def init(server_name) do
    :gproc
    server_name
    |> proc_name
    |> :gproc.reg

    {:ok, %Etimer{}}
  end

  @doc false
  @spec handle_call({:start_timer, term, non_neg_integer, cb},
    pid, %Etimer{running: list(tuple)}) ::
    {:reply, :ok, %Etimer{running: list(tuple)}}
  def handle_call({:start_timer, tname, timeout, cb = {_m, _f, _a}}, _from, state) do
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
  @spec handle_call({:stop_timer, term},
    pid, %Etimer{running: list(tuple)}) ::
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
  @spec handle_info({:timeout, reference, {term, cb}},
    %Etimer{running: list(tuple)}) ::
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
