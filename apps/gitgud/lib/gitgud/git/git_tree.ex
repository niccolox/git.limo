defmodule GitGud.GitTree do
  @moduledoc """
  Defines a Git tree object.
  """

  alias GitRekt.Git

  alias GitGud.GitTreeEntry

  defstruct [:oid, :__git__]

  @type t :: %__MODULE__{oid: Git.oid, __git__: Git.tree}

  @doc """
  Returns the tree entry of the given `tree`, given its `oid`.
  """
  @spec by_id(t, Git.oid) :: {:ok, GitTreeEntry.t} | {:error, term}
  def by_id(%__MODULE__{__git__: tree}, oid) do
    with {:ok, handle} <- Git.object_repository(tree),
         {:ok, mode, type, oid, name} <- Git.tree_byid(tree, oid), do:
      {:ok, resolve_entry({mode, type, oid, name}, handle)}
  end

  @doc """
  Returns the tree entry of the given `tree`, given its `path`.
  """
  @spec by_path(t, Path.t) :: {:ok, GitTreeEntry.t} | {:error, term}
  def by_path(%__MODULE__{__git__: tree}, path) do
    with {:ok, handle} <- Git.object_repository(tree),
         {:ok, mode, type, oid, name} <- Git.tree_bypath(tree, path), do:
      {:ok, resolve_entry({mode, type, oid, name}, handle)}
  end

  @doc """
  Returns the number of tree entries of the given `tree`.
  """
  @spec count(t) :: {:ok, non_neg_integer} | {:error, term}
  def count(%__MODULE__{__git__: tree} = _tree) do
    Git.tree_count(tree)
  end

  @doc """
  Return the tree entry at `index` of the given `tree`.
  """
  @spec nth(t, non_neg_integer) :: {:ok, GitTreeEntry.t} | {:error, term}
  def nth(%__MODULE__{__git__: tree} = _tree, index) do
    with {:ok, handle} <- Git.object_repository(tree),
         {:ok, entry} <- Git.tree_nth(tree, index), do:
      {:ok, resolve_entry(entry, handle)}
  end

  @doc """
  Returns all the tree entries of the given `tree`.
  """
  @spec entries(t) :: {:ok, [GitTreeEntry.t]} | {:error, term}
  def entries(%__MODULE__{__git__: tree} = _tree) do
    with {:ok, handle} <- Git.object_repository(tree),
         {:ok, entries} <- Git.tree_list(tree), do:
      {:ok, Enum.map(entries, &resolve_entry(&1, handle))}
  end

  #
  # Helpers
  #

  defp resolve_entry({mode, type, oid, name}, handle) do
    case Git.object_lookup(handle, oid) do
      {:ok, ^type, entry} ->
        %GitTreeEntry{oid: oid, name: name, mode: mode, type: type, __git__: entry}
      {:error, _reason} ->
        nil
    end
  end
end
