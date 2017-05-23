defmodule Letmeguess.RoomChannel do
  use Phoenix.Channel

  alias Letmeguess.Game.Server, as: GameServer

  def join("room:" <> room_id, %{"user_name" => user_name}, socket) do
    GameServer.create(room_id)
    result = GameServer.join(room_id, user_name)
    if result do
      send(self(), %{"joined" => user_name, "room" => room_id})
      socket = socket |> assign(:room_id, room_id)
      {:ok, socket |> assign(:user_name, user_name)}
    else
      {:error, %{reason: "user_name_exists"}}
    end
  end

  def handle_info(%{"joined" => user_name, "room" => room_id}, socket) do
      broadcast socket, "new_msg", %{msg: "", user: user_name, type: "joined"}
      GameServer.start(room_id)
      {:noreply, socket}
  end

  def handle_in("new_msg", %{"msg" => body}, socket) do
    user_name = socket.assigns[:user_name]
    room_id = socket.assigns[:room_id]
    word = GameServer.get_word(room_id)
    if word != body do
      broadcast(socket, "new_msg", %{msg: body, user: user_name,
                                     type: "user_msg"})
    else
      broadcast(socket, "new_msg",%{msg: "#{user_name} found the word",
                                    user: user_name, type: "user_msg"})
    end
    {:noreply, socket}
  end

  def leave(_reason, socket) do
    {:ok, socket}
  end

  def terminate(_reason, socket) do
    user_name = socket.assigns[:user_name]
    room_id = socket.assigns[:room_id]
    GameServer.leave(room_id, user_name)
    broadcast socket, "new_msg", %{msg: "", user: user_name, type: "left"}
    {:shutdown, :closed}
  end

end
