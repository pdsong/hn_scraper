
# 爬取首页热门新闻（5条示例）
mix run -e "HnScraper.print_top_news(5)"
# 爬取最新新闻（5条示例）
mix run -e "HnScraper.print_newest_news(5)"
# 爬取全部300条
mix run -e "HnScraper.print_top_news()"
mix run -e "HnScraper.print_newest_news()"
mix run -e "IO.puts(HnScraper.fetch_top_news_json(10))"
mix run -e "IO.puts(HnScraper.fetch_newest_news_json(10))"
mix run -e "HnScraper.Scheduler.next_run_time()"


# ========== 数据库说明 (SQLite) ==========
# 本项目使用本地 SQLite 数据库 (hn_scraper.db)
# 数据库文件会自动创建，表结构也会在运行时自动初始化
# 无需手动安装或配置数据库服务

# 查看数据库内容（需安装 sqlite3 命令行工具）
# sqlite3 hn_scraper.db "SELECT * FROM hn_news LIMIT 5;"

# 表结构说明：
# id          INTEGER PRIMARY KEY AUTOINCREMENT
# rank_id     INTEGER
# up_id       TEXT UNIQUE
# url         TEXT
# title       TEXT
# news_type   TEXT (default 'newest')
# news_time   TEXT
# create_time TEXT
# insert_time TEXT




# ========== 新增：数据入库命令 ==========
# 同时爬取热门和最新新闻并存入数据库（5条）
mix run -e 'HnScraper.run("2026-02-09 19:00:00", 5)'

# 同时爬取全部300条并入库
mix run -e 'HnScraper.run("2026-02-09 19:00:00")'

# 如果数据库连接失败，数据会自动保存到 save_after_error/ 目录
数据入库成功时显示 ✓，失败时自动保存到 save_after_error/ 目录
备份文件命名格式：{news_time}_top.txt / {news_time}_newest.txt



✅ GenServer 调度器已实现并测试成功！

新增文件：

lib/hn_scraper/scheduler.ex - 调度器（每整点运行）
lib/hn_scraper/application.ex - 应用启动入口
启动方式：

bash
# 前台运行（带日志）
mix run --no-halt
# 后台运行
nohup mix run --no-halt > scheduler.log 2>&1 &
# 使用 iex 交互式运行
iex -S mix
输出示例：

🚀 HnScraper 调度器启动
⏰ 下次运行时间: 2026-02-09 20:00:00 (3 分钟后)
API 接口：

HnScraper.Scheduler.next_run_time() - 查看下次运行时间
HnScraper.Scheduler.run_now() - 立即手动触发
HnScraper.Scheduler.stop() - 停止调度器

✅ 数据库模块已修改为使用本地 SQLite 数据库！

主要变更：

依赖变更：将 postgrex 替换为 exqlite (SQLite 驱动)。
代码重构：重写了 lib/hn_scraper/db.ex，现在会自动创建 hn_scraper.db 文件和相关表结构。
零配置：不再需要安装或配置 PostgreSQL 服务，程序运行时会自动初始化数据库。
验证结果：

运行爬虫测试成功：✓ top 新闻入库成功 / ✓ newest 新闻入库成功。
如果入库失败，降级保存到文件功能的逻辑保持不变。
使用方法（保持不变）：

bash
mix run -e 'HnScraper.run("2026-02-09 21:30:00", 5)'
查看数据： 你可以使用 sqlite3 命令行工具（如果安装了）查看数据：



mix run -e "HnScraper.Scheduler.next_run_time()"
这只是启动应用 -> 打印下次运行时间 -> 然后立即退出了。
如何让它在后台持续运行？
你需要使用 --no-halt 参数让应用保持运行，并配合 nohup 放入后台：

bash
# 后台启动命令
nohup mix run --no-halt > scraper.log 2>&1 &
如何验证它在运行？
启动后，你可以通过以下命令检查：

查看进程：ps aux | grep mix 或 ps aux | grep beam
查看日志：tail -f scraper.log

基于 SQLite 的新版爬虫 正在后台运行 (PID: 1910891)。

之前的 PG 版本 已经停止，不会与新版本冲突。

常用维护命令：

查看运行状态
bash
ps aux | grep mix
查看实时日志
bash
tail -f scraper.log
(注：如果日志有延迟，是因为 buffering，可以等待片刻或观察数据库文件变化)
停止服务
bash
pkill -f "mix run --no-halt"