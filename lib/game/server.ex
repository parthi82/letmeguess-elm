defmodule Letmeguess.Game.Server do
  use GenServer

  require Logger

  @player_init %{"drawn" => false, "score" => 0}

  alias Letmeguess.Endpoint

  ## Client Api

  def create(game_id) do
    case GenServer.whereis(ref(game_id)) do
      nil ->
        Supervisor.start_child(Letmeguess.Game.Supervisor, [game_id])
      _game_ref ->
        {:error, :game_already_exists}
    end
  end

  def stop_game(game_id) do
    Logger.debug "Stopping game #{game_id} in supervisor"
    pid = GenServer.whereis(ref(game_id))
    Supervisor.terminate_child(Letmeguess.Game.Supervisor, pid)
  end

  def join(game_id, player) do
    try_call(game_id, {:join, player})
  end

  def leave(game_id, player) do
    try_cast(game_id, {:leave, player})
  end

  def start(game_id) do
    try_cast(game_id, {:start_game, game_id})
  end

  def get_word(game_id) do
    try_call(game_id, :get_word)
  end

  def start_link(game_id) do
    GenServer.start_link(__MODULE__, :ok, name: ref(game_id))
  end


 ## Server Callbacks

  def init(:ok) do
    {:ok, %{"started" => false, "players" => %{}}}
  end

  def handle_call({:join, player}, _from, state) do
    state
    |> get_in(["players", player])
    |> join_game(player, state)
  end

  def handle_call(:get_word, _from, state) do
    {:reply, state["word"], state}
  end


  def handle_cast({:start_game, game_id}, state) do
    new_state = state
                |> Map.get("players")
                |> Enum.filter(&(!elem(&1, 1)["drawn"]))
                |> start_game(state, game_id)
    {:noreply, new_state}
  end

  def handle_cast({:leave, player}, state) do
    {_, new_state} = pop_in(state, ["players", player])
    {:noreply, new_state}
  end

  def handle_info({:time_up, game_id}, state) do
    IO.puts "time up!"
    players = state
              |> Map.get("players")
              |> Enum.filter(&(!elem(&1, 1)["drawn"]))
    if players == [] do
      IO.puts "game ended"
      stop_game(game_id)
    else
      {player, _} = Enum.random(players)
      Endpoint.broadcast("room:#{game_id}", "new_msg",
                %{msg: "#{player} is going to draw",
                  user: player, type: "user_msg"})
      state = state
              |> put_in(["players", player, "drawn"], true)
              |> Map.put("started", true)
              |> Map.merge(%{"started" => true, "word" => "apple"})
      set_timer({:time_up, game_id}, 10_000)
      {:noreply, state}
    end

  end

 ## helper functions

  defp join_game(value, player, state) do
    case value do
      nil -> {:reply, true, put_in(state["players"][player], @player_init)}
      _ -> {:reply, false, state}
    end
  end

  defp start_game(players, state, game_id) do
    if length(players) >= 2 and !state["started"] do
      IO.puts "starting the game"
      {player, _} = Enum.random(players)
      Endpoint.broadcast("room:#{game_id}", "new_msg",
                %{msg: "#{player} is going to draw",
                  user: player, type: "user_msg"})
      state = state
              |> put_in(["players", player, "drawn"], true)
              |> Map.put("started", true)
              |> Map.merge(%{"started" => true, "word" => "apple"})
      set_timer({:time_up, game_id}, 20_000)
      state
    else
      state
    end
  end

  defp set_timer(msg, time) do
    Process.send_after(self(), msg, time)
  end

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

  defp ref(game_id) do
    {:global, {:game, game_id}}
  end

end
