defmodule LetmeguessWeb.RoomChannelTest  do
  use LetmeguessWeb.ChannelCase

  alias LetmeguessWeb.UserSocket

  setup do
    {:ok, socket} = connect UserSocket, %{"some" => "params"}
    {:ok, socket: socket}
  end

  test "user_name is assigned while joining a channel", %{socket: socket} do
     {:ok, %{}, socket} = join socket, "room:test", %{"user_name" => "test_user"}
     assert socket.assigns[:user_name] == "test_user"
  end

  test "new_msg broadcasts to room:test with user, msg in the payload", %{socket: socket} do
      {:ok, %{}, socket} = join socket, "room:test", %{"user_name" => "test_user"}
      @endpoint.subscribe("room:test")
      push socket, "new_msg", %{"msg": "test"}
      assert_broadcast "new_msg", %{msg: "test", user: "test_user", type: "user_msg"}
  end

  test "broadcasts are pushed to the client", %{socket: socket} do
    {:ok, %{}, socket} = join socket, "room:test", %{"user_name" => "test_user"}
    broadcast_from! socket, "broadcast", %{"some" => "data"}
    assert_push "broadcast", %{"some" => "data"}
  end

  test "broadcast when someone joins the room", %{socket: socket} do
     {:ok, _, _} = subscribe_and_join(socket, "room:test", %{"user_name" => "test_user"})
     assert_broadcast "new_msg", %{msg: "", user: "test_user", type: "joined"}
  end

end
