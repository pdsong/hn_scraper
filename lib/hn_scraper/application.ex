defmodule HnScraper.Application do
  @moduledoc """
  HnScraper 应用程序入口

  启动时自动启动调度器
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # 启动调度器
      HnScraper.Scheduler
    ]

    opts = [strategy: :one_for_one, name: HnScraper.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
