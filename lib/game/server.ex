defmodule Letmeguess.Game.Server do
  use GenServer

  require Logger

  ## Client Api

  def create(game_id) do
    case GenServer.whereis(ref(game_id)) do
      nil ->
        Supervisor.start_child(Letmeguess.Game.Supervisor, [game_id])
      _game_ref ->
        {:error, :game_already_exists}
    end
  end

  def join(game_id, player) do
    try_call(game_id, {:join, player})
  end

  def leave(game_id, player) do
    try_cast(game_id, {:leave, player})
  end

  def start_link(game_id) do
    GenServer.start_link(__MODULE__, :ok, name: ref(game_id))
  end


 ## Server Callbacks

  def init(:ok) do
    {:ok, %{'started' => false}}
  end

  def handle_call({:join, player}, _from, state) do
    case Map.get(state, player) do
      nil -> {:reply, true, Map.put(state, player, player_defaults())}
      _value ->   {:reply, false, state}
    end
  end

  def handle_cast({:leave, player}, state) do
    {:noreply, Map.delete(state, player)}
  end


 ## helper functions

  defp try_call(game_id, message) do
   case GenServer.whereis(ref(game_id)) do
     nil ->
       {:error, :game_not_found}
     server ->
       GenServer.call(server, message)
   end
  end

  defp try_cast(game_id, message) do
   case GenServer.whereis(ref(game_id)) do
     nil ->
       {:error, :game_not_found}
     server ->
       GenServer.cast(server, message)
   end
  end

  defp player_defaults, do: %{"drawn": false, "score": 0}

  defp ref(game_id) do
    {:global, {:game, game_id}}
  end

end
