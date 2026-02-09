defmodule HnScraper do
  @moduledoc """
  Hacker News 新闻爬虫模块

  提供两个爬取方法:
  - fetch_top_news/1: 爬取首页热门新闻 (https://news.ycombinator.com)
  - fetch_newest_news/1: 爬取最新新闻 (https://news.ycombinator.com/newest)

  主入口:
  - run/1: 同时爬取热门和最新新闻，存入数据库

  每页30条，最多爬取300条（10页）
  """

  @base_url "https://news.ycombinator.com"
  @top_url @base_url
  @newest_url "#{@base_url}/newest"
  @items_per_page 30
  @max_items 300
  @max_pages div(@max_items, @items_per_page)
  @save_dir "save_after_error"

  # ============================================
  # 主入口函数
  # ============================================

  @doc """
  主运行函数，同时爬取热门和最新新闻并存入数据库

  ## 参数
    - news_time: 新闻时间字符串，如 "2026-02-09 19:00:00"
    - max_items: 最大爬取数量，默认300

  ## 示例
      iex> HnScraper.run("2026-02-09 19:00:00")
      iex> HnScraper.run("2026-02-09 19:00:00", 100)
  """
  def run(news_time, max_items \\ @max_items) do
    IO.puts("========================================")
    IO.puts("开始爬取 Hacker News - #{news_time}")
    IO.puts("========================================")

    # 确保保存目录存在
    ensure_save_dir()

    # 同时爬取热门和最新新闻
    top_task = Task.async(fn -> fetch_top_news(max_items) end)
    newest_task = Task.async(fn -> fetch_newest_news(max_items) end)

    top_news = Task.await(top_task, :infinity)
    newest_news = Task.await(newest_task, :infinity)

    IO.puts("\n========================================")
    IO.puts("爬取完成，开始入库...")
    IO.puts("========================================")

    # 入库或保存到文件
    save_news(top_news, "top", news_time)
    save_news(newest_news, "newest", news_time)

    IO.puts("\n========================================")
    IO.puts("全部处理完成！")
    IO.puts("========================================")

    %{top: length(top_news), newest: length(newest_news)}
  end

  # ============================================
  # 公共 API
  # ============================================

  @doc """
  爬取 Hacker News 首页热门新闻
  """
  def fetch_top_news(max_items \\ @max_items) do
    IO.puts("\n=== 爬取首页热门新闻 ===")
    fetch_news_from_url(@top_url, max_items)
  end

  @doc """
  爬取 Hacker News 最新新闻
  """
  def fetch_newest_news(max_items \\ @max_items) do
    IO.puts("\n=== 爬取最新新闻 ===")
    fetch_news_from_url(@newest_url, max_items)
  end

  @doc """
  打印首页热门新闻
  """
  def print_top_news(max_items \\ @max_items) do
    news = fetch_top_news(max_items)
    print_news_list(news)
  end

  @doc """
  打印最新新闻
  """
  def print_newest_news(max_items \\ @max_items) do
    news = fetch_newest_news(max_items)
    print_news_list(news)
  end

  @doc """
  将首页热门新闻导出为 JSON 格式
  """
  def fetch_top_news_json(max_items \\ @max_items) do
    fetch_top_news(max_items) |> to_json()
  end

  @doc """
  将最新新闻导出为 JSON 格式
  """
  def fetch_newest_news_json(max_items \\ @max_items) do
    fetch_newest_news(max_items) |> to_json()
  end

  # ============================================
  # 私有函数 - 数据保存
  # ============================================

  # 保存新闻到数据库，失败则保存到文件
  defp save_news(news_list, news_type, news_time) do
    IO.puts("正在保存 #{news_type} 新闻 (#{length(news_list)} 条)...")

    case HnScraper.DB.insert_news(news_list, news_type, news_time) do
      {:ok, count} ->
        IO.puts("✓ #{news_type} 新闻入库成功，共 #{count} 条")
        :ok

      {:error, reason} ->
        IO.puts("✗ #{news_type} 新闻入库失败: #{inspect(reason)}")
        IO.puts("  正在保存到本地文件...")
        save_to_file(news_list, news_type, news_time)
    end
  end

  # 保存到本地文件
  defp save_to_file(news_list, news_type, news_time) do
    # 格式化文件名中的时间（替换特殊字符）
    safe_time = news_time |> String.replace(~r/[:\s]/, "_")
    filename = "#{@save_dir}/#{safe_time}_#{news_type}.txt"

    content =
      news_list
      |> Enum.map(fn item ->
        "#{item.rank_id}. [#{item.up_id}] #{item.title}\n   URL: #{item.url}"
      end)
      |> Enum.join("\n\n")

    header = """
    ========================================
    Hacker News #{String.upcase(news_type)} News
    News Time: #{news_time}
    Saved At: #{DateTime.utc_now() |> DateTime.to_string()}
    Total: #{length(news_list)} items
    ========================================

    """

    case File.write(filename, header <> content) do
      :ok ->
        IO.puts("  ✓ 已保存到 #{filename}")
        {:ok, filename}

      {:error, reason} ->
        IO.puts("  ✗ 保存文件失败: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # 确保保存目录存在
  defp ensure_save_dir do
    unless File.exists?(@save_dir) do
      File.mkdir_p!(@save_dir)
      IO.puts("创建目录: #{@save_dir}")
    end
  end

  # ============================================
  # 私有函数 - 核心爬取逻辑
  # ============================================

  defp fetch_news_from_url(start_url, max_items) do
    max_pages = min(div(max_items + @items_per_page - 1, @items_per_page), @max_pages)

    fetch_all_pages(start_url, max_pages, 1, [])
    |> Enum.take(max_items)
    |> add_rank_ids()
  end

  defp fetch_all_pages(_url, max_pages, current_page, acc) when current_page > max_pages do
    Enum.reverse(acc)
  end

  defp fetch_all_pages(url, max_pages, current_page, acc) do
    IO.puts("正在爬取第 #{current_page} 页: #{url}")

    case fetch_page(url) do
      {:ok, {items, next_url}} ->
        new_acc = Enum.reverse(items) ++ acc

        if next_url && current_page < max_pages do
          Process.sleep(500)
          fetch_all_pages(next_url, max_pages, current_page + 1, new_acc)
        else
          Enum.reverse(new_acc)
        end

      {:error, reason} ->
        IO.puts("爬取失败: #{inspect(reason)}")
        Enum.reverse(acc)
    end
  end

  defp fetch_page(url) do
    headers = [
      {"User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
    ]

    case HTTPoison.get(url, headers, follow_redirect: true, timeout: 10_000, recv_timeout: 10_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, parse_page(body)}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "HTTP错误: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  # ============================================
  # 私有函数 - HTML解析
  # ============================================

  defp parse_page(html) do
    {:ok, document} = Floki.parse_document(html)

    items = parse_news_items(document)
    next_url = parse_next_page(document)

    {items, next_url}
  end

  defp parse_news_items(document) do
    document
    |> Floki.find("tr.athing")
    |> Enum.map(&parse_single_item/1)
    |> Enum.filter(&(&1 != nil))
  end

  defp parse_single_item(item) do
    up_id = Floki.attribute(item, "id") |> List.first()
    title_link = Floki.find(item, ".titleline > a") |> List.first()

    case title_link do
      nil ->
        nil

      _ ->
        title = Floki.text(title_link) |> String.trim()
        url = Floki.attribute(title_link, "href") |> List.first() |> normalize_url()

        if up_id && title != "" do
          %{
            up_id: up_id,
            url: url,
            title: title,
            rank_id: nil
          }
        else
          nil
        end
    end
  end

  defp normalize_url(nil), do: nil
  defp normalize_url("item?" <> _ = path), do: "#{@base_url}/#{path}"
  defp normalize_url("/" <> _ = path), do: "#{@base_url}#{path}"
  defp normalize_url(url), do: url

  defp parse_next_page(document) do
    more_link = Floki.find(document, "a.morelink") |> List.first()

    case more_link do
      nil ->
        nil

      _ ->
        href = Floki.attribute(more_link, "href") |> List.first()
        if href, do: "#{@base_url}/#{href}", else: nil
    end
  end

  # ============================================
  # 私有函数 - 辅助工具
  # ============================================

  defp add_rank_ids(items) do
    items
    |> Enum.with_index(1)
    |> Enum.map(fn {item, index} -> %{item | rank_id: index} end)
  end

  defp print_news_list(news) do
    Enum.each(news, fn item ->
      IO.puts("#{item.rank_id}. [#{item.up_id}] #{item.title}")
      IO.puts("   URL: #{item.url}")
      IO.puts("")
    end)

    IO.puts("共爬取 #{length(news)} 条新闻")
    news
  end

  defp to_json(news) do
    news
    |> Enum.map(fn item ->
      ~s({"rank_id": #{item.rank_id}, "up_id": "#{item.up_id}", "url": "#{escape_json(item.url)}", "title": "#{escape_json(item.title)}"})
    end)
    |> Enum.join(",\n  ")
    |> then(&"[\n  #{&1}\n]")
  end

  defp escape_json(nil), do: ""

  defp escape_json(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
    |> String.replace("\r", "\\r")
    |> String.replace("\t", "\\t")
  end
end
