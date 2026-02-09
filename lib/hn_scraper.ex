defmodule HnScraper do
  @moduledoc """
  Hacker News 新闻爬虫模块

  提供两个爬取方法:
  - fetch_top_news/1: 爬取首页热门新闻 (https://news.ycombinator.com)
  - fetch_newest_news/1: 爬取最新新闻 (https://news.ycombinator.com/newest)

  每页30条，最多爬取300条（10页）

  返回格式:
  [
    %{rank_id: 1, up_id: "46943551", url: "https://...", title: "..."},
    ...
  ]
  """

  @base_url "https://news.ycombinator.com"
  @top_url @base_url
  @newest_url "#{@base_url}/newest"
  @items_per_page 30
  @max_items 300
  @max_pages div(@max_items, @items_per_page)

  # ============================================
  # 公共 API
  # ============================================

  @doc """
  爬取 Hacker News 首页热门新闻

  ## 参数
    - max_items: 最大爬取数量，默认300

  ## 返回值
    返回新闻列表，每条新闻包含:
    - rank_id: 排名序号 (1-300)
    - up_id: HN 新闻的唯一ID
    - url: 新闻链接
    - title: 新闻标题

  ## 示例
      iex> HnScraper.fetch_top_news(10)
      [
        %{rank_id: 1, up_id: "46943551", url: "https://example.com/article", title: "Article Title"},
        ...
      ]
  """
  def fetch_top_news(max_items \\ @max_items) do
    IO.puts("=== 爬取首页热门新闻 ===")
    fetch_news_from_url(@top_url, max_items)
  end

  @doc """
  爬取 Hacker News 最新新闻

  ## 参数
    - max_items: 最大爬取数量，默认300

  ## 返回值
    返回新闻列表，每条新闻包含:
    - rank_id: 排名序号 (1-300)
    - up_id: HN 新闻的唯一ID
    - url: 新闻链接
    - title: 新闻标题

  ## 示例
      iex> HnScraper.fetch_newest_news(10)
      [
        %{rank_id: 1, up_id: "46943551", url: "https://example.com/article", title: "Article Title"},
        ...
      ]
  """
  def fetch_newest_news(max_items \\ @max_items) do
    IO.puts("=== 爬取最新新闻 ===")
    fetch_news_from_url(@newest_url, max_items)
  end

  @doc """
  打印首页热门新闻（用于调试）
  """
  def print_top_news(max_items \\ @max_items) do
    news = fetch_top_news(max_items)
    print_news_list(news)
  end

  @doc """
  打印最新新闻（用于调试）
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
  # 私有函数 - 核心爬取逻辑
  # ============================================

  # 从指定URL开始爬取新闻
  defp fetch_news_from_url(start_url, max_items) do
    max_pages = min(div(max_items + @items_per_page - 1, @items_per_page), @max_pages)

    fetch_all_pages(start_url, max_pages, 1, [])
    |> Enum.take(max_items)
    |> add_rank_ids()
  end

  # 递归爬取所有页面 - 终止条件
  defp fetch_all_pages(_url, max_pages, current_page, acc) when current_page > max_pages do
    Enum.reverse(acc)
  end

  # 递归爬取所有页面 - 递归体
  defp fetch_all_pages(url, max_pages, current_page, acc) do
    IO.puts("正在爬取第 #{current_page} 页: #{url}")

    case fetch_page(url) do
      {:ok, {items, next_url}} ->
        new_acc = Enum.reverse(items) ++ acc

        if next_url && current_page < max_pages do
          # 添加延迟避免请求过快
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

  # 爬取单个页面，返回新闻列表和下一页URL
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

  # 解析页面HTML，提取新闻列表和下一页链接
  defp parse_page(html) do
    {:ok, document} = Floki.parse_document(html)

    items = parse_news_items(document)
    next_url = parse_next_page(document)

    {items, next_url}
  end

  # 解析所有新闻条目
  # HN页面结构:
  # - 每条新闻由两行组成: .athing (标题行) 和 .subtext (元信息行)
  # - .athing 包含 id 属性和标题链接
  defp parse_news_items(document) do
    document
    |> Floki.find("tr.athing")
    |> Enum.map(&parse_single_item/1)
    |> Enum.filter(&(&1 != nil))
  end

  # 解析单条新闻
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

  # 规范化URL（处理相对路径）
  defp normalize_url(nil), do: nil
  defp normalize_url("item?" <> _ = path), do: "#{@base_url}/#{path}"
  defp normalize_url("/" <> _ = path), do: "#{@base_url}#{path}"
  defp normalize_url(url), do: url

  # 解析下一页链接
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

  # 为新闻列表添加排名序号
  defp add_rank_ids(items) do
    items
    |> Enum.with_index(1)
    |> Enum.map(fn {item, index} -> %{item | rank_id: index} end)
  end

  # 打印新闻列表
  defp print_news_list(news) do
    Enum.each(news, fn item ->
      IO.puts("#{item.rank_id}. [#{item.up_id}] #{item.title}")
      IO.puts("   URL: #{item.url}")
      IO.puts("")
    end)

    IO.puts("共爬取 #{length(news)} 条新闻")
    news
  end

  # 转换为JSON格式
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
