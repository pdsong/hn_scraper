
# 爬取首页热门新闻（5条示例）
mix run -e "HnScraper.print_top_news(5)"
# 爬取最新新闻（5条示例）
mix run -e "HnScraper.print_newest_news(5)"
# 爬取全部300条
mix run -e "HnScraper.print_top_news()"
mix run -e "HnScraper.print_newest_news()"
# 获取JSON格式
mix run -e "IO.puts(HnScraper.fetch_top_news_json(10))"
mix run -e "IO.puts(HnScraper.fetch_newest_news_json(10))"