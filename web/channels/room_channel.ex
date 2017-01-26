defmodule Letmeguess.RoomChannel do
  use Phoenix.Channel

  def join("room:" <> _room_id, %{"user_name" => user_name}, socket) do
    send(self, %{"joined" => user_name})
    {:ok, socket |> assign(:user_name, user_name)}
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
    broadcast socket, "new_msg", %{msg: "", user: user_name, type: "left"}
    {:shutdown, :closed}
  end

end
