defmodule GameServer do
  use GenServer

  ## Client API
  def start_link(name) do
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  def start_game(server, room) do
    GenServer.call(server, {:start_game, room})
  end

  def end_game(server, room) do
    GenServer.cast(server, {:end_game, room})
  end

  ## Server CallBacks
  def handle_call({:start_game, room}, _from, state) do
    value = get_defaults()
    case Map.get(state, room) do
      nil -> {:reply, value, Map.put(state, room, value)}
      _ -> {:reply, false, state}
    end
  end

  defp get_defaults(word \\ "apple") do
    blanks = word
            |> String.codepoints
            |> (fn(list) -> (for _ <- list, do: "_") end).()
    %{"word" => word, "blanks" => blanks}
  end

  def handle_cast({:end_game, room}, state) do
    {:noreply, Map.delete(state, room)}
  end

  def init(:ok) do
    {:ok, %{}}
  end

end
