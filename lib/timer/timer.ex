defmodule Etimer.Timer do
  @moduledoc false

  @doc false
  def start_timer(t, pid, args) do
    :erlang.start_timer(t, pid, args)
  end

  @doc false
  def cancel_timer(tref) do
    :erlang.cancel_timer(tref)
  end
end
