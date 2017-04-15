defmodule GameServer do
  use GenServer

  ## Client API
  def start_link(name) do
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  def join(server, room , player) do
    GenServer.call(server, {:join, room, player})
  end

  def leave(server, room, player) do
    GenServer.cast(server, {:leave, room, player})
  end

  ## Server CallBacks
  def handle_call({:join, room, player}, _from, state) do
    {:reply, join_room(room, player), state}
  end

  def handle_cast({:leave, room, player}, state) do
    case :ets.lookup(:game_room, room) do
      [] -> true
      [{^room, data}]-> remove_player(data, player, room)
    end
    {:noreply, state}
  end

  def remove_player(data, player, room) do
    {_, new_data} = Map.pop(data, player)
    :ets.insert(:game_room, {room, new_data})
  end


  defp join_room(room, player) do
    case :ets.lookup(:game_room, room) do
      [] -> :ets.insert(:game_room, {room, %{player => player_defaults()}})
      [{^room, data}]-> player_exists?(data, player, room)
    end
  end

  defp player_exists?(data, player, room) do
    case Map.get(data, player) do
      nil -> update_players(data, player, room)
      _ -> false
    end
  end

  defp update_players(data, player, room) do
    data = Map.put(data, player, player_defaults())
    :ets.insert(:game_room, {room, data})
    true
  end

  defp player_defaults, do: %{"drew": false, "score": 0}

  def init(:ok) do
    :ets.new(:game_room, [:named_table, :set, :private])
    {:ok, %{}}
  end

end
