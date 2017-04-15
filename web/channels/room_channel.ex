defmodule Letmeguess.RoomChannel do
  use Phoenix.Channel

  def join("room:" <> room_id, %{"user_name" => user_name}, socket) do
    result = GameServer.join(GameServer, room_id, user_name)
    if result do
      send(self(), %{"joined" => user_name})
      socket = socket |> assign(:room_id, room_id)
      {:ok, socket |> assign(:user_name, user_name)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_info(%{"joined" => user_name}, socket) do
      broadcast socket, "new_msg", %{msg: "", user: user_name, type: "joined"}
      {:noreply, socket}
  end

  def handle_in("new_msg", %{"msg" => body}, socket) do
    user_name = socket.assigns[:user_name]
    broadcast socket, "new_msg", %{msg: body, user: user_name, type: "user_msg"}
    {:noreply, socket}
  end

  def leave(_reason, socket) do
    {:ok, socket}
  end

  def terminate(_reason, socket) do
    user_name = socket.assigns[:user_name]
    room_id = socket.assigns[:room_id]
    GameServer.leave(GameServer, room_id, user_name)
    broadcast socket, "new_msg", %{msg: "", user: user_name, type: "left"}
    {:shutdown, :closed}
  end

end
