defmodule Letmeguess.RoomChannel do
  use Phoenix.Channel

  def join("room:" <> _room_id, _message, socket) do
    {:ok, socket}
  end

  def handle_in("new_msg", %{"msg" => body}, socket) do
    broadcast! socket, "new_msg", %{msg: body}
    {:noreply, socket}
  end
end
