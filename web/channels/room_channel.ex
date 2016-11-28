defmodule Letmeguess.RoomChannel do
  use Phoenix.Channel

  def join("room:" <> _room_id, %{"user_name" => user_name}, socket) do
    {:ok, socket |> assign(:user_name, user_name)}
  end

  def handle_in("new_msg", %{"msg" => body}, socket) do
    user_name = socket.assigns[:user_name]
    broadcast socket, "new_msg", %{msg: body, user: user_name}
    {:noreply, socket}
  end
end
