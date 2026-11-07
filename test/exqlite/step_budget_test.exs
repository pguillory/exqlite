defmodule Exqlite.StepBudgetTest do
  use ExUnit.Case, async: true
  alias Exqlite.Sqlite3, as: SQL

  test "wide rows are rejected by the native budget before returning any cell" do
    {:ok, db} = SQL.open(":memory:")
    on_exit(fn -> SQL.close(db) end)
    sql = "SELECT " <> Enum.join(List.duplicate("?1", 2000), ",")
    {:ok, stmt} = SQL.prepare_single(db, sql)
    :ok = SQL.bind(stmt, [String.duplicate("x", 1000)])
    assert {:error, :result_too_large} = SQL.step(db, stmt, 10_000)
    assert :ok = SQL.release(db, stmt)
    {:ok, check} = SQL.prepare_single(db, "SELECT 1")
    assert {:row, [1]} = SQL.step(db, check, 8)
    assert :done = SQL.step(db, check, 8)
    :ok = SQL.release(db, check)
  end

  test "budget accounting has an exact boundary and preserves legacy stepping" do
    {:ok, db} = SQL.open(":memory:")
    on_exit(fn -> SQL.close(db) end)
    {:ok, stmt} = SQL.prepare_single(db, "SELECT 42, 1.5, NULL, 'hey', x'0102'")
    assert {:error, :result_too_large} = SQL.step(db, stmt, 21)
    assert {:row, [42, 1.5, nil, "hey", <<1, 2>>]} = SQL.step(db, stmt, 22)
    assert :done = SQL.step(db, stmt, 22)
    assert {:row, [42, 1.5, nil, "hey", <<1, 2>>]} = SQL.step(db, stmt)
    :ok = SQL.release(db, stmt)
  end
end
