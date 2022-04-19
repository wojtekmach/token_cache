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
  use GenServer

  @registry TokenCache.Registry

  def start_link(config) when is_list(config) do
    name = Keyword.fetch!(config, :name)
    GenServer.start_link(__MODULE__, config, name: via(name))
  end

  defp via(name) do
    {:via, Registry, {@registry, name}}
  end

  def fetch(name) do
    case fetch_cache(name) do
      {:hit, token} ->
        {:ok, token}

      :miss ->
        GenServer.call(via(name), :fetch)
    end
  end

  def fetch!(name) do
    case fetch(name) do
      {:ok, token} -> token
      {:error, exception} -> raise exception
    end
  end

  @impl true
  def init(config) do
    config = struct!(TokenCache.Config, config)
    state = %{config: config}

    case config.prefetch do
      :sync ->
        {_result, state} = fetch_token(state)
        {:ok, state}

      :async ->
        {:ok, state, {:continue, :prefetch}}
    end
  end

  @impl true
  def handle_continue(:prefetch, state) do
    {_result, state} = fetch_token(state)
    {:noreply, state}
  end

  @impl true
  def handle_call(:fetch, _from, state) do
    case fetch_cache(state.config.name) do
      {:hit, token} ->
        {:reply, {:ok, token}, state}

      :miss ->
        {result, state} = fetch_token(state)
        {:reply, result, state}
    end
  end

  @impl true
  def handle_info(:refetch, state) do
    {_result, state} = fetch_token(state)
    {:noreply, state}
  end

  defp fetch_token(state) do
    case state.config.fetch.() do
      {:ok, %{token: _, expires_in: _} = token} ->
        store_cache(state.config.name, token)
        Process.send_after(self(), :refetch, token.expires_in * 1000)
        {{:ok, token}, state}

      {:error, _} = error ->
        {error, state}
    end
  end

  defp fetch_cache(name) do
    [{_pid, token}] = Registry.lookup(@registry, name)

    if token do
      {:hit, token}
    else
      :miss
    end
  end

  defp store_cache(name, token) do
    Registry.update_value(@registry, name, fn _ -> token end)
  end
end

defmodule TokenCache.Config do
  @moduledoc false

  defstruct [:name, :fetch, prefetch: :async]
end
