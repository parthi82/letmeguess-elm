defmodule Letmeguess.Game.Server do
  use GenServer

  require Logger



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

  def stop_game(state) do
    game_id = state["game_id"]
    Logger.debug "Stopping game #{game_id}"
    pid = GenServer.whereis(ref(game_id))
    Supervisor.terminate_child(Letmeguess.Game.Supervisor, pid)
  end

  def join(game_id, player) do
    try_call(game_id, {:join, player})
  end

  def leave(game_id, player) do
    try_cast(game_id, {:leave, player})
  end

  def after_join(game_id, player) do
    try_cast(game_id, {:after_join, player})
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
    if !state["started"] do
      state
      |> get_in(["players", player])
      |> join_game(player, state)
    else
      {:reply, false, state}
    end
  end

  def handle_call(:get_word, _from, state) do
    {:reply, state["word"], state}
  end

  def handle_cast({:after_join, player}, state) do
    game_id = state["game_id"]
    players =  Map.values(state["players"])
    Endpoint.broadcast("room:#{game_id}", "joined",
                      %{players: players, joined: player})
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

  def handle_info(:count_down, state) do
    Logger.debug "countdown over, start game!"
    {:noreply, manage_turn(state)}
  end



 ## helper functions

  defp join_game(value, player, state) do
    case value do
      nil -> {:reply, true, put_in(state["players"][player],
                                   player_default(player))}
      _ -> {:reply, false, state}
    end
  end


  defp get_players(state) do
    state
    |> Map.get("players", [])
    |> Enum.filter(&(!elem(&1, 1)["drawn"]))
  end

  defp manage_play(state) do
    started = state["started"]
    Logger.debug "started : #{started}"
    cond do
      !started -> start_game(state)
      started -> next_round(state)
    end
  end

  defp next_round(state) do
    players = get_players(state)
    if Enum.empty?(players) do
      Logger.debug "game ended"
      stop_game(state)
    else
      count_down(state)
    end
  end

  defp count_down(state) do
    timer = set_timer(:count_down, 5_000)
    Map.put(state, "count_down", timer)
  end

  defp manage_turn(state) do
    game_id = state["game_id"]
    {player, _} = get_players(state)
                  |> Enum.random()

    Endpoint.broadcast("room:#{game_id}", "going_to_draw",
                       %{ "name" => player, "score": 0})

    still_guessing = Map.get(state, "players")
                  |> Map.keys()
                  |> List.delete(player)
    state = state
            |> put_in(["players", player, "drawn"], true)
            |> Map.merge(%{"word" => "cat", "started" => true,
                           "still_guessing" => still_guessing})
    Endpoint.broadcast("room:#{game_id}", "word_update",
                        %{ "word" =>["*", "*", "*"]})
    timer = set_timer(:time_up, 20_000)
    Map.put(state, "timer", timer)
  end

  defp start_game(state) do
    players = get_players(state)
    if length(players) >= 2 do
       count_down_ref = state["count_down"]
       if is_reference(count_down_ref) do
         :erlang.cancel_timer(count_down_ref)
       end
       count_down(state)
    else
      state
    end
  end

  defp handle_found_word(state, player) do
    still_guessing = state["still_guessing"]
    if Enum.member?(still_guessing, player) do
      game_id = state["game_id"]
      {_, state} = get_and_update_in(state, ["players", player, "score"],
                                     &{&1, &1 + 10})
      Endpoint.broadcast("room:#{game_id}", "score",
                         get_in(state, ["players", player]))
      still_guessing = List.delete(still_guessing, player)
      if Enum.empty?(still_guessing) do
        :erlang.cancel_timer(state["timer"])
        next_round(state)
      else
        Map.put(state, "still_guessing", still_guessing)
      end
    else
      state
    end
  end

  defp player_default(name), do: %{"drawn" => false, "score" => 0, "name" => name}

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
