defmodule Exqlite.PrepareSingleTest do
  use ExUnit.Case, async: true
  alias Exqlite.Sqlite3, as: SQL

  test "strict prepare recognizes SQLite statements rather than semicolons" do
    {:ok, db} = SQL.open(":memory:")
    on_exit(fn -> SQL.close(db) end)

    for sql <- ["SELECT ';'; -- end", "SELECT 1; /* comment */ ;", "SELECT 'x'';y'"] do
      assert {:ok, stmt} = SQL.prepare_single(db, sql)
      assert :ok = SQL.release(db, stmt)
    end

    for sql <- [
          "",
          "-- empty",
          ";",
          "SELECT 1; SELECT 2",
          "SELECT 1; nonsense",
          "SELECT 1; SELECT * FROM missing"
        ] do
      assert {:error, :multiple_statements} = SQL.prepare_single(db, sql)
    end

    assert {:error, :invalid_sql} = SQL.prepare_single(db, "SELECT 1\0; SELECT 2")
    :ok = SQL.execute(db, "PRAGMA foreign_keys=ON")

    assert {:error, :multiple_statements} =
             SQL.prepare_single(db, "SELECT 1; PRAGMA foreign_keys=OFF")

    {:ok, check} = SQL.prepare(db, "PRAGMA foreign_keys")
    assert {:ok, [[1]]} = SQL.fetch_all(db, check)
    :ok = SQL.release(db, check)
    :ok = SQL.set_authorizer(db, [:pragma])

    assert {:error, :multiple_statements} =
             SQL.prepare_single(db, "SELECT 1; PRAGMA user_version")

    :ok = SQL.set_authorizer(db, [])
    :ok = SQL.execute(db, "CREATE TABLE t (x)")

    assert {:ok, stmt} =
             SQL.prepare_single(
               db,
               "CREATE TRIGGER tr AFTER INSERT ON t BEGIN UPDATE t SET x=2; UPDATE t SET x=3; END;"
             )

    assert :ok = SQL.release(db, stmt)
    assert {:ok, old} = SQL.prepare(db, "SELECT 1; SELECT 2")
    assert :ok = SQL.release(db, old)
  end
end
