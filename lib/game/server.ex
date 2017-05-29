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
    try_cast(game_id, :start_game)
  end

  def handle_guess(game_id, player, msg) do
    try_cast(game_id, {:guess, player, msg})
  end

  def get_word(game_id) do
    try_call(game_id, :get_word)
  end

  def start_link(game_id) do
    GenServer.start_link(__MODULE__, game_id, name: ref(game_id))
  end


 ## Server Callbacks

  def init(game_id) do
    {:ok, %{"started" => false, "players" => %{}, "game_id" => game_id}}
  end

  def handle_call({:join, player}, _from, state) do
    state
    |> get_in(["players", player])
    |> join_game(player, state)
  end

  def handle_call(:get_word, _from, state) do
    {:reply, state["word"], state}
  end

  def handle_cast(:start_game, state) do
    {:noreply, manage_play(state)}
  end

  def handle_cast({:guess, player, msg}, state) do
    if state["word"] != msg do
      game_id = state["game_id"]
      Endpoint.broadcast("room:#{game_id}", "new_msg",
               %{msg: msg,
                 user: player, type: "user_msg"})
      {:noreply, state}
    else
      new_state = handle_found_word(state, player)
      {:noreply, new_state}
    end
  end

  def handle_cast({:leave, player}, state) do
    {_, new_state} = pop_in(state, ["players", player])
    {:noreply, new_state}
  end

  def handle_info(:time_up, state) do
    Logger.debug "time up!"
    {:noreply, manage_play(state)}
  end



 ## helper functions

  defp join_game(value, player, state) do
    case value do
      nil -> {:reply, true, put_in(state["players"][player], @player_init)}
      _ -> {:reply, false, state}
    end
  end


  defp get_players(state) do
    state
    |> Map.get("players")
    |> Enum.filter(&(!elem(&1, 1)["drawn"]))
  end

  defp manage_play(state) do
    started = state["started"]
    cond do
      !started -> start_game(state)
      started -> next_round(state)
    end
  end

  defp next_round(state) do
    game_id = state["game_id"]
    players = get_players(state)
    if players == [] do
      Logger.debug "game ended"
      stop_game(game_id)
    else
      manage_turn(players, state)
    end
  end

  defp manage_turn(players, state) do
    game_id = state["game_id"]
    {player, _} = Enum.random(players)
    Endpoint.broadcast("room:#{game_id}", "new_msg",
              %{msg: "#{player} is going to draw",
                user: player, type: "user_msg"})

    still_guessing = Map.get(state, "players")
                  |> Map.keys()
                  |> List.delete(player)
    state = state
            |> put_in(["players", player, "drawn"], true)
            |> Map.merge(%{"word" => "cat", "still_guessing" => still_guessing})
    Endpoint.broadcast("room:#{game_id}", "word_update",
                        %{ "word" =>["*", "*", "*"]})
    timer = set_timer(:time_up, 20_000)
    Map.put(state, "timer", timer)
  end

  defp start_game(state) do
    players = get_players(state)
    state = Map.put(state, "started", true)
    if length(players) >= 2 do
      manage_turn(players, state)
    else
      state
    end
  end

  defp handle_found_word(state, player) do
    still_guessing = state["still_guessing"]
    if Enum.member?(still_guessing, player) do
      game_id = state["game_id"]
      Endpoint.broadcast("room:#{game_id}", "new_msg",
               %{msg: "#{player} found the word",
                 user: player, type: "user_msg"})

      still_guessing = List.delete(still_guessing, player)
      if still_guessing == [] do
        :erlang.cancel_timer(state["timer"])
        next_round(state)
      else
        Map.put(state, "still_guessing", still_guessing)
      end
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
