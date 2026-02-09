defmodule HnScraper.Scheduler do
  @moduledoc """
  定时调度器，每整点小时自动运行爬虫任务

  使用 GenServer + Process.send_after 实现自调度
  """
  use GenServer
  require Logger

  # ============================================
  # 公共 API
  # ============================================

  @doc """
  启动调度器
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  获取下次运行时间
  """
  def next_run_time do
    GenServer.call(__MODULE__, :next_run_time)
  end

  @doc """
  立即执行一次（不影响定时调度）
  """
  def run_now do
    GenServer.cast(__MODULE__, :run_now)
  end

  @doc """
  停止调度器
  """
  def stop do
    GenServer.stop(__MODULE__)
  end

  # ============================================
  # GenServer 回调
  # ============================================

  @impl true
  def init(_opts) do
    Logger.info("🚀 HnScraper 调度器启动")

    # 计算下次运行时间并调度
    next_time = calculate_next_hour()
    ms_until_next = ms_until(next_time)

    Logger.info("⏰ 下次运行时间: #{format_datetime(next_time)} (#{div(ms_until_next, 60_000)} 分钟后)")

    timer_ref = Process.send_after(self(), :run, ms_until_next)

    state = %{
      next_run_time: next_time,
      timer_ref: timer_ref,
      run_count: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:next_run_time, _from, state) do
    {:reply, state.next_run_time, state}
  end

  @impl true
  def handle_cast(:run_now, state) do
    Logger.info("📢 手动触发运行")
    do_run()
    {:noreply, state}
  end

  @impl true
  def handle_info(:run, state) do
    Logger.info("⏰ 定时任务触发")

    # 执行爬虫任务
    do_run()

    # 调度下一次运行
    next_time = calculate_next_hour()
    ms_until_next = ms_until(next_time)

    Logger.info("⏰ 下次运行时间: #{format_datetime(next_time)}")

    timer_ref = Process.send_after(self(), :run, ms_until_next)

    new_state = %{
      state
      | next_run_time: next_time,
        timer_ref: timer_ref,
        run_count: state.run_count + 1
    }

    {:noreply, new_state}
  end

  # ============================================
  # 私有函数
  # ============================================

  # 执行爬虫任务
  defp do_run do
    news_time = format_current_hour()
    Logger.info("🔄 开始爬取任务，news_time: #{news_time}")

    try do
      result = HnScraper.run(news_time)
      Logger.info("✅ 爬取完成: top=#{result.top}, newest=#{result.newest}")
    rescue
      e ->
        Logger.error("❌ 爬取失败: #{Exception.message(e)}")
    end
  end

  # 计算下一个整点时间
  defp calculate_next_hour do
    # 转为 UTC+8
    now = DateTime.now!("Etc/UTC") |> DateTime.add(8 * 3600, :second)

    # 下一个整点
    next_hour =
      now
      |> Map.put(:minute, 0)
      |> Map.put(:second, 0)
      |> Map.put(:microsecond, {0, 0})
      # 加1小时
      |> DateTime.add(3600, :second)

    next_hour
  end

  # 计算到目标时间的毫秒数
  defp ms_until(target_time) do
    now = DateTime.now!("Etc/UTC") |> DateTime.add(8 * 3600, :second)
    diff_seconds = DateTime.diff(target_time, now, :second)

    # 确保至少等待1秒
    max(diff_seconds * 1000, 1000)
  end

  # 格式化当前整点时间为字符串
  defp format_current_hour do
    now = DateTime.now!("Etc/UTC") |> DateTime.add(8 * 3600, :second)

    now
    |> Map.put(:minute, 0)
    |> Map.put(:second, 0)
    |> format_datetime()
  end

  # 格式化 DateTime 为字符串
  defp format_datetime(dt) do
    "#{dt.year}-#{pad(dt.month)}-#{pad(dt.day)} #{pad(dt.hour)}:#{pad(dt.minute)}:#{pad(dt.second)}"
  end

  defp pad(num), do: String.pad_leading(Integer.to_string(num), 2, "0")
end
