defmodule EtimerTest do
  use ExUnit.Case
  doctest Etimer

  alias Etimer.Timer

  #
  # API tests
  #
  test "start_link test" do
    assert {:ok, pid1} = Etimer.start_link(:my_timer)
    assert {:ok, pid2} = Etimer.start_link(:my_2nd_timer)
    refute pid1 == pid2
  end

  # 
  # GenServer callbacks tests
  #
  test "init test" do
    assert {:ok, %Etimer{}} == Etimer.init(:my_timer)
  end

  test "start a new timer" do
    cb = {IO, :inspect, ["hello"]}
    {:reply, :ok, state} = {:start_timer, :my_timer, 42_000, cb}
    |> Etimer.handle_call(self, %Etimer{})

    assert Enum.count(state.running) == 1
    assert {:my_timer, t_ref} = Enum.at(state.running, 0)
    assert is_reference(t_ref)
  end

  test "starting an existing timer restarts it" do
    cb = {IO, :inspect, ["hello"]}
    {:reply, :ok, state} = {:start_timer, :my_timer, 10_000, cb}
    |> Etimer.handle_call(self, %Etimer{})

    assert Enum.count(state.running) == 1
    assert {:my_timer, t_ref} = Enum.at(state.running, 0)
    assert is_reference(t_ref)

    {:reply, :ok, state} = {:start_timer, :my_timer, 10_000, cb}
    |> Etimer.handle_call(self, state)
    assert Enum.count(state.running) == 1
    assert {:my_timer, t_ref2} = Enum.at(state.running, 0)
    assert is_reference(t_ref2)
    refute t_ref == t_ref2
  end

  test "stop a not running timer" do
    assert {:reply, :not_running, _state} = {:stop_timer, :my_timer}
    |> Etimer.handle_call(self, %Etimer{})
  end
  
  test "stop a running timer" do
    cb = {IO, :inspect, ["hello"]}
    {:reply, :ok, state} = {:start_timer, :my_timer, 10_000, cb}
    |> Etimer.handle_call(self, %Etimer{})
    assert Enum.count(state.running) == 1

    {:reply, response, state} = {:stop_timer, :my_timer}
    |> Etimer.handle_call(self, state)
    assert Enum.count(state.running) == 0

    assert {:ok, x} = response
    assert is_integer(x)
  end

  test "callback is fired on timer event" do
    cb = {Process, :send, [self, "hello", []]}

    state = %Etimer{running: [{:my_timer, :aref}]}

    {:noreply, state} = {:timeout, :aref, {:my_timer, cb}}
    |> Etimer.handle_info(state)
    assert Enum.count(state.running) == 0

    assert_receive "hello"
  end

  test "no action if timer reference is not found" do
    cb = {IO, :inspect, ["hello"]}

    state = %Etimer{running: [{:a_timer, :aref}]}

    {:noreply, new_state} = {:timeout, :bref, {:b_timer, cb}}
    |> Etimer.handle_info(state)
    assert Enum.count(state.running) == 1
    assert state == new_state
  end

  test "stop call" do
    {:stop, :normal, :ok, _state} = Etimer.handle_call(:stop, self, %Etimer{})
  end

  test "any cast" do
    {:noreply, state} = Etimer.handle_cast(:any, %Etimer{})
    assert state == %Etimer{}
  end

end
