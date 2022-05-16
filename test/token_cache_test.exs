defmodule TokenCacheTest do
  use ExUnit.Case, async: true

  test "it works", c do
    pid = self()

    start_supervised!(
      {TokenCache,
       name: c.test,
       fetch: fn ->
         send(pid, :fetching)
         {:ok, System.unique_integer([:positive, :monotonic]), 50}
       end}
    )

    assert_receive :fetching
    token1 = TokenCache.fetch(c.test)
    token2 = TokenCache.fetch(c.test)
    assert token2 == token1

    assert_receive :fetching
    token3 = TokenCache.fetch(c.test)
    assert token3 != token2
  end

  @tag :capture_log
  test "handles sync prefetch error", c do
    pid = self()

    fetch = fn ->
      send(pid, :fetching)

      mock_responses([
        {:error, RuntimeError.exception("oops")},
        {:error, RuntimeError.exception("oops")},
        {:ok, "abcd", 1000}
      ])
    end

    delay = fn
      0 -> 10
      1 -> 10
    end

    start_supervised!(
      {TokenCache, name: c.test, fetch: fetch, prefetch: :sync, retry_delay: delay}
    )

    assert_receive :fetching
    assert_receive :fetching
    assert_receive :fetching
    refute_receive _
  end

  @tag :capture_log
  test "handles async prefetch error", c do
    pid = self()

    fetch = fn ->
      send(pid, :fetching)

      mock_responses([
        {:error, RuntimeError.exception("oops")},
        {:error, RuntimeError.exception("oops")},
        {:ok, "abcd", 1000}
      ])
    end

    delay = fn
      0 -> 10
      1 -> 10
    end

    start_supervised!(
      {TokenCache,
       name: c.test, fetch: fetch, prefetch: :async, max_retries: 2, retry_delay: delay},
      restart: :temporary
    )

    assert_receive :fetching
    assert_receive :fetching
    assert_receive :fetching
    refute_receive _
  end

  @tag :capture_log
  test "keeps failing", c do
    pid = self()

    fetch = fn ->
      send(pid, :fetching)
      {:error, RuntimeError.exception("oops")}
    end

    delay = fn
      0 -> 10
      1 -> 10
    end

    start_supervised!(
      {TokenCache,
       name: c.test, fetch: fetch, prefetch: :async, max_retries: 2, retry_delay: delay},
      restart: :temporary
    )

    assert_receive :fetching
    assert_receive :fetching
    assert_receive :fetching
    refute_receive _

    assert {:noproc, _} = catch_exit(TokenCache.fetch(c.test))
  end

  defp mock_responses(responses) do
    key = :mock_responses

    unless Process.get(key) do
      Process.put(key, responses)
    end

    [head | tail] = Process.get(key)
    Process.put(key, tail)
    head
  end
end
