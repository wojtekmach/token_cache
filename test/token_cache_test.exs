defmodule TokenCacheTest do
  use ExUnit.Case, async: true

  test "it works", c do
    pid = self()

    start_supervised!(
      {TokenCache,
       name: c.test,
       fetch: fn ->
         send(pid, :fetching)
         {:ok, %{token: make_ref(), expires_in: 1}}
       end}
    )

    assert_receive :fetching
    token1 = TokenCache.fetch!(c.test)
    token2 = TokenCache.fetch!(c.test)
    assert token2.token == token1.token

    assert_receive :fetching, 2000
    token3 = TokenCache.fetch!(c.test)
    assert token3.token != token2.token
  end
end
