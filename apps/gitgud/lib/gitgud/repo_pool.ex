defmodule GitGud.RepoPool do
  @moduledoc """
  Dynamic pool of Git repository agent processes.
  """
  use DynamicSupervisor

  alias GitRekt.GitAgent

  alias GitGud.Repo
  alias GitGud.RepoStorage
  alias GitGud.RepoRegistry

  @max_children_per_pool 5

  @doc """
  Starts the pool as part of a supervision tree.
  """
  @spec start_link(keyword) :: Supervisor.on_start
  def start_link(opts \\ []) do
    opts = Keyword.put(opts, :name, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, [], opts)
  end

  @doc """
  Starts a pool supervisor for the given `repo`.
  """
  @spec start_pool(Repo.t, keyword) :: Supervisor.on_start
  def start_pool(repo, opts \\ []) do
    via_registry = {:via, Registry, {RepoRegistry, "#{repo.owner_login}/#{repo.name}"}}
    opts = Keyword.put(opts, :name, via_registry)
    DynamicSupervisor.start_link(__MODULE__, {Path.join(repo.owner_login, repo.name), RepoStorage.workdir(repo)}, opts)
  end

  @doc """
  Starts a `GitRekt.GitAgent` process for the given `repo`.
  """
  @spec start_agent(Repo.t) :: {:ok, pid} | {:error, term}
  def start_agent(repo) do
    pool_child_spec = %{id: :pool, start: {__MODULE__, :start_pool, [repo]}, restart: :temporary}
    agent_child_spec = %{id: :agent, start: {GitAgent, :start_link, []}, restart: :temporary}
    case DynamicSupervisor.start_child(__MODULE__, pool_child_spec) do
      {:ok, pool} ->
        DynamicSupervisor.start_child(pool, agent_child_spec)
      {:error, {:already_started, pool}} ->
        DynamicSupervisor.start_child(pool, agent_child_spec)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns a `GitRekt.GitAgent` process for the given `repo`.
  """
  @spec get_or_create(Repo.t) :: {:ok, pid} | {:error, term}
  def get_or_create(%Repo{} = repo) do
    case start_agent(repo) do
      {:ok, agent} ->
        {:ok, agent}
      {:error, :max_children} ->
        lookup_agent(repo)
      {:error, reason} ->
        {:error, reason}
    end
  end

  #
  # Callbacks
  #

  @impl true
  def init([]) do
    :ets.new(__MODULE__, [:public, :named_table])
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def init({path, workdir}) do
    :ets.insert(__MODULE__, {path, -1})
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_children: @max_children_per_pool,
      extra_arguments: [
        workdir,
        [
          cache: GitAgent.init_cache(workdir, []),
          idle_timeout: 120_000
        ]
      ]
    )
  end

  #
  # Helpers
  #

  defp lookup_agent(%Repo{} = repo), do: lookup_agent(Path.join(repo.owner_login, repo.name))
  defp lookup_agent(path) do
    case Registry.lookup(GitGud.RepoRegistry, path) do
      [{pool, nil}] ->
        children = DynamicSupervisor.which_children(pool)
        index = :ets.update_counter(__MODULE__, path, {2, 1, @max_children_per_pool - 1, 0})
        case Enum.at(children, rem(index, length(children))) do
          {:undefined, agent, :worker, [_mod]} when is_pid(agent) ->
            {:ok, agent}
          nil ->
            {:error, "pool out of bounds for #{path}"}
        end
      [] ->
        {:error, "no pool available for #{path}"}
    end
  end
end
