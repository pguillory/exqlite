defmodule Exqlite.LimitTest do
  use ExUnit.Case, async: true
  alias Exqlite.Sqlite3, as: SQL

  test "length limit rejects generated values inside SQLite and is per connection" do
    {:ok, db} = SQL.open(":memory:")
    {:ok, other} = SQL.open(":memory:")

    on_exit(fn ->
      SQL.close(db)
      SQL.close(other)
    end)

    assert {:ok, old} = SQL.limit(db, :length, 100)
    assert old > 100
    assert {:ok, 100} = SQL.limit(db, :length, -1)
    {:ok, stmt} = SQL.prepare_single(db, "SELECT zeroblob(101)")
    assert {:error, "string or blob too big"} = SQL.fetch_all(db, stmt)
    :ok = SQL.release(db, stmt)
    {:ok, stmt} = SQL.prepare_single(other, "SELECT length(zeroblob(101))")
    assert {:ok, [[101]]} = SQL.fetch_all(other, stmt)
    :ok = SQL.release(other, stmt)
    :ok = SQL.close(db)
    assert {:error, :connection_closed} = SQL.limit(db, :length, 100)
  end
end
