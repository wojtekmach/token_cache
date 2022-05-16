defmodule TokenCacheTest do
  use ExUnit.Case, async: true

  test "it works", c do
    pid = self()

    start_supervised!(
      {TokenCache,
       name: c.test,
       refresh_in: 50,
       fetch: fn ->
         send(pid, :fetching)
         {:ok, %{token: make_ref()}}
       end}
    )

    assert_receive :fetching
    token1 = TokenCache.fetch!(c.test)
    token2 = TokenCache.fetch!(c.test)
    assert token2.token == token1.token

    assert_receive :fetching
    token3 = TokenCache.fetch!(c.test)
    assert token3.token != token2.token
  end
end
