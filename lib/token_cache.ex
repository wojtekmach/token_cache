defmodule TokenCache.Application do
  @moduledoc false

  def start(_type, _args) do
    children = [
      {Registry, name: TokenCache.Registry, keys: :unique}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end

defmodule TokenCache do
  @moduledoc """
  TokenCache is a simple cache server with automatic refreshes.

  It also has the following features:

    * sync/async prefetching
    * automatic retries on errors
  """

  use GenServer
  require Logger

  @registry TokenCache.Registry

  @schema [
    name: [
      type: :any,
      doc: "The name of the server.",
      required: true
    ],
    fetch: [
      type: {:fun, 0},
      doc: """
      The function to fetch the token.

        It should return either:

          * `{:ok, token, refresh_in}` where `refresh_in` is time in millseconds
            after which the token will be automatically refreshed

          * `{:error, exception}`
      """,
      required: true
    ],
    prefetch: [
      type: {:in, [:sync, :async]},
      doc: "How to prefetch the token.",
      default: :async
    ],
    max_retries: [
      type: :non_neg_integer,
      doc: "The maximum number of retries on fetch errors.",
      default: 10
    ],
    retry_delay: [
      type: {:fun, 1},
      doc: """
      The function to calculate the delay time in milliseconds between retry attempts.
      It receives the retry attempt number (starting at `0`) and it returns the next
      delay time. The default function returns 1000ms, 2000ms, 4000ms, etc.
      """
    ]
  ]

  @doc """
  Start the token cache server.

  ## Options

  #{NimbleOptions.docs(@schema)}
  """
  def start_link(options) when is_list(options) do
    config =
      options
      |> Keyword.put_new(:retry_delay, &default_retry_delay/1)
      |> NimbleOptions.validate!(@schema)
      |> Map.new()

    GenServer.start_link(__MODULE__, config, name: via(config.name))
  end

  @doc """
  Fetch the token from cache.
  """
  def fetch(name, timeout \\ 5000) do
    get_cache(name) || GenServer.call(via(name), :fetch, timeout)
  end

  @impl true
  def init(config) do
    state = %{config: config}

    case config.prefetch do
      :sync ->
        case fetch_token(state) do
          {:ok, _token} ->
            :ok

          {:error, _} ->
            schedule_refresh(0)
        end

        {:ok, state}

      :async ->
        {:ok, state, {:continue, :prefetch}}
    end
  end

  @impl true
  def handle_call(:fetch, _from, state) do
    if token = get_cache(state.config.name) do
      {:reply, token, state}
    else
      case fetch_token_with_retries(state) do
        {:ok, token} ->
          {:reply, token, state}

        {:error, exception} ->
          {:stop, :shutdown, exception}
      end
    end
  end

  @impl true
  def handle_continue(:prefetch, state) do
    handle_refresh(state)
  end

  @impl true
  def handle_info(:refresh, state) do
    handle_refresh(state)
  end

  defp handle_refresh(state) do
    case fetch_token_with_retries(state) do
      {:ok, _token} ->
        {:noreply, state}

      {:error, exception} ->
        {:stop, :shutdown, exception}
    end
  end

  defp fetch_token_with_retries(state) do
    fetch_token_with_retries(0, state)
  end

  defp fetch_token_with_retries(attempt, state) do
    case fetch_token(state) do
      {:ok, token} ->
        {:ok, token}

      {:error, exception} ->
        if attempt < state.config.max_retries do
          Process.sleep(state.config.retry_delay.(attempt))
          fetch_token_with_retries(attempt + 1, state)
        else
          {:error, exception}
        end
    end
  end

  defp default_retry_delay(attempt) do
    1000 * Integer.pow(attempt, 2)
  end

  defp fetch_token(state) do
    case state.config.fetch.() do
      {:ok, token, refresh_in} ->
        put_cache(state.config.name, token)
        schedule_refresh(refresh_in)
        {:ok, token}

      {:error, exception} = error ->
        Logger.error("fetching token failed: #{Exception.message(exception)}")
        error
    end
  end

  defp schedule_refresh(time) do
    Process.send_after(self(), :refresh, time)
  end

  defp via(name) do
    {:via, Registry, {@registry, name}}
  end

  defp get_cache(name) do
    case Registry.lookup(@registry, name) do
      [{_pid, value}] -> value
      [] -> nil
    end
  end

  defp put_cache(name, token) do
    Registry.update_value(@registry, name, fn _ -> token end)
  end
end
