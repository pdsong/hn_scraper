defmodule HnScraper.DB do
  @moduledoc """
  数据库操作模块，负责将爬取的新闻数据存入 PostgreSQL
  """

  @db_config [
    hostname: "localhost",
    port: 5433,
    username: "postgres",
    password: "postgres",
    database: "hn_scraper"
  ]

  @doc """
  启动数据库连接
  """
  def start_link do
    Postgrex.start_link(@db_config)
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
    case start_link() do
      {:ok, conn} ->
        try do
          result = do_batch_insert(conn, news_list, news_type, news_time)
          GenServer.stop(conn)
          result
        rescue
          e ->
            GenServer.stop(conn)
            {:error, Exception.message(e)}
        end

      {:error, reason} ->
        {:error, "数据库连接失败: #{inspect(reason)}"}
    end
  end

  # 执行批量插入
  defp do_batch_insert(conn, news_list, news_type, news_time) do
    # 解析 news_time
    parsed_time = parse_news_time(news_time)
    now = NaiveDateTime.utc_now()

    sql = """
    INSERT INTO hn_news (rank_id, up_id, url, title, news_type, news_time, create_time, insert_time)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    ON CONFLICT (up_id) DO UPDATE SET
      rank_id = EXCLUDED.rank_id,
      title = EXCLUDED.title,
      url = EXCLUDED.url,
      insert_time = EXCLUDED.insert_time
    """

    success_count =
      news_list
      |> Enum.reduce(0, fn item, count ->
        params = [
          item.rank_id,
          item.up_id,
          item.url,
          item.title,
          news_type,
          parsed_time,
          now,
          now
        ]

        case Postgrex.query(conn, sql, params) do
          {:ok, _} -> count + 1
          {:error, _} -> count
        end
      end)

    {:ok, success_count}
  end

  # 解析 news_time 字符串为 NaiveDateTime
  defp parse_news_time(news_time) when is_binary(news_time) do
    case NaiveDateTime.from_iso8601(news_time) do
      {:ok, dt} ->
        dt

      {:error, _} ->
        # 尝试解析 "YYYY-MM-DD HH:MM:SS" 格式
        case String.split(news_time, " ") do
          [date, time] ->
            case NaiveDateTime.from_iso8601("#{date}T#{time}") do
              {:ok, dt} -> dt
              _ -> NaiveDateTime.utc_now()
            end

          _ ->
            NaiveDateTime.utc_now()
        end
    end
  end

  defp parse_news_time(_), do: NaiveDateTime.utc_now()
end
