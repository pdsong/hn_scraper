defmodule HnScraper.DB do
  @moduledoc """
  数据库操作模块，使用本地 SQLite 数据库存储新闻数据
  """

  @db_path "hn_scraper.db"

  @doc """
  初始化数据库，创建表（如果不存在）
  """
  def init do
    {:ok, conn} = Exqlite.Sqlite3.open(@db_path)

    create_table_sql = """
    CREATE TABLE IF NOT EXISTS hn_news (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      rank_id INTEGER NOT NULL,
      up_id TEXT NOT NULL UNIQUE,
      url TEXT,
      title TEXT NOT NULL,
      news_type TEXT DEFAULT 'newest',
      news_time TEXT,
      create_time TEXT DEFAULT CURRENT_TIMESTAMP,
      insert_time TEXT DEFAULT CURRENT_TIMESTAMP
    )
    """

    :ok = Exqlite.Sqlite3.execute(conn, create_table_sql)

    # 创建索引
    :ok = Exqlite.Sqlite3.execute(conn, "CREATE INDEX IF NOT EXISTS idx_up_id ON hn_news(up_id)")

    :ok =
      Exqlite.Sqlite3.execute(
        conn,
        "CREATE INDEX IF NOT EXISTS idx_news_type ON hn_news(news_type)"
      )

    :ok =
      Exqlite.Sqlite3.execute(
        conn,
        "CREATE INDEX IF NOT EXISTS idx_create_time ON hn_news(create_time)"
      )

    Exqlite.Sqlite3.close(conn)
    :ok
  end

  @doc """
  批量插入新闻数据到数据库

  ## 参数
    - news_list: 新闻列表
    - news_type: 新闻类型 ("top" 或 "newest")
    - news_time: 新闻时间（外部传入）

  ## 返回值
    - {:ok, count} 成功插入的数量
    - {:error, reason} 插入失败原因
  """
  def insert_news(news_list, news_type, news_time) do
    # 确保表存在
    init()

    case Exqlite.Sqlite3.open(@db_path) do
      {:ok, conn} ->
        try do
          result = do_batch_insert(conn, news_list, news_type, news_time)
          Exqlite.Sqlite3.close(conn)
          result
        rescue
          e ->
            Exqlite.Sqlite3.close(conn)
            {:error, Exception.message(e)}
        end

      {:error, reason} ->
        {:error, "数据库连接失败: #{inspect(reason)}"}
    end
  end

  # 执行批量插入
  defp do_batch_insert(conn, news_list, news_type, news_time) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.to_string()

    sql = """
    INSERT INTO hn_news (rank_id, up_id, url, title, news_type, news_time, create_time, insert_time)
    VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
    ON CONFLICT(up_id) DO UPDATE SET
      rank_id = excluded.rank_id,
      title = excluded.title,
      url = excluded.url,
      insert_time = excluded.insert_time
    """

    {:ok, statement} = Exqlite.Sqlite3.prepare(conn, sql)

    success_count =
      news_list
      |> Enum.reduce(0, fn item, count ->
        :ok =
          Exqlite.Sqlite3.bind(statement, [
            item.rank_id,
            item.up_id,
            item.url,
            item.title,
            news_type,
            news_time,
            now,
            now
          ])

        case Exqlite.Sqlite3.step(conn, statement) do
          :done ->
            Exqlite.Sqlite3.reset(statement)
            count + 1

          _ ->
            Exqlite.Sqlite3.reset(statement)
            count
        end
      end)

    Exqlite.Sqlite3.release(conn, statement)
    {:ok, success_count}
  end

  @doc """
  查询新闻数据

  ## 参数
    - opts: 可选参数
      - :news_type - 新闻类型 ("top" 或 "newest")
      - :limit - 返回数量限制

  ## 示例
      HnScraper.DB.query_news(news_type: "top", limit: 10)
  """
  def query_news(opts \\ []) do
    init()

    {:ok, conn} = Exqlite.Sqlite3.open(@db_path)

    news_type = Keyword.get(opts, :news_type)
    limit = Keyword.get(opts, :limit, 100)

    {sql, params} =
      if news_type do
        {"SELECT * FROM hn_news WHERE news_type = ?1 ORDER BY id DESC LIMIT ?2",
         [news_type, limit]}
      else
        {"SELECT * FROM hn_news ORDER BY id DESC LIMIT ?1", [limit]}
      end

    {:ok, statement} = Exqlite.Sqlite3.prepare(conn, sql)
    :ok = Exqlite.Sqlite3.bind(statement, params)

    rows = fetch_all_rows(conn, statement, [])

    Exqlite.Sqlite3.release(conn, statement)
    Exqlite.Sqlite3.close(conn)

    rows
  end

  # 获取所有行
  defp fetch_all_rows(conn, statement, acc) do
    case Exqlite.Sqlite3.step(conn, statement) do
      {:row, row} ->
        [id, rank_id, up_id, url, title, news_type, news_time, create_time, insert_time] = row

        item = %{
          id: id,
          rank_id: rank_id,
          up_id: up_id,
          url: url,
          title: title,
          news_type: news_type,
          news_time: news_time,
          create_time: create_time,
          insert_time: insert_time
        }

        fetch_all_rows(conn, statement, [item | acc])

      :done ->
        Enum.reverse(acc)
    end
  end

  @doc """
  获取数据库文件路径
  """
  def db_path, do: @db_path
end
