defmodule GameServerTest do
  use ExUnit.Case, async: true

  setup do
    GameServer.start_link
  end

end
