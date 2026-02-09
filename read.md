
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





-- 1. 创建数据库
CREATE DATABASE hn_scraper;
-- 2. 连接到数据库
\c hn_scraper
-- 3. 创建新闻表
CREATE TABLE hn_news (
    id SERIAL PRIMARY KEY,                          -- 自增主键
    rank_id INTEGER NOT NULL,                       -- 排名序号
    up_id VARCHAR(20) NOT NULL UNIQUE,              -- HN新闻唯一ID
    url TEXT,                                       -- 新闻链接
    title TEXT NOT NULL,                            -- 新闻标题
    news_type VARCHAR(20) DEFAULT 'newest',         -- 新闻类型: 'top' 或 'newest'
    news_time TIMESTAMP,                            -- 新闻发布时间
    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,-- 记录创建时间
    insert_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- 数据插入时间

-- 4. 创建索引（提高查询效率）
CREATE INDEX idx_hn_news_up_id ON hn_news(up_id);
CREATE INDEX idx_hn_news_news_type ON hn_news(news_type);
CREATE INDEX idx_hn_news_create_time ON hn_news(create_time);
-- 5. 添加注释
COMMENT ON TABLE hn_news IS 'Hacker News 新闻数据表';
COMMENT ON COLUMN hn_news.rank_id IS '排名序号';
COMMENT ON COLUMN hn_news.up_id IS 'HN新闻唯一ID';
COMMENT ON COLUMN hn_news.url IS '新闻链接';
COMMENT ON COLUMN hn_news.title IS '新闻标题';
COMMENT ON COLUMN hn_news.news_type IS '新闻类型: top(热门) 或 newest(最新)';
COMMENT ON COLUMN hn_news.news_time IS '新闻发布时间';
COMMENT ON COLUMN hn_news.create_time IS '记录创建时间';
COMMENT ON COLUMN hn_news.insert_time IS '数据插入时间';    


表结构说明：

字段	类型	说明
id	SERIAL	自增主键
rank_id	INTEGER	爬取时的排名序号
up_id	VARCHAR(20)	HN新闻唯一ID（设为UNIQUE防重复）
url	TEXT	新闻链接
title	TEXT	新闻标题
news_type	VARCHAR(20)	区分热门(top)或最新(newest)
news_time	TIMESTAMP	新闻发布时间
create_time	TIMESTAMP	记录创建时间（自动填充）
insert_time	TIMESTAMP	数据插入时间（自动填充）
创建完成后你可以用 \dt 查看表，用 \d hn_news 查看表结构




# ========== 新增：数据入库命令 ==========
# 同时爬取热门和最新新闻并存入数据库（5条）
mix run -e 'HnScraper.run("2026-02-09 19:00:00", 5)'

# 同时爬取全部300条并入库
mix run -e 'HnScraper.run("2026-02-09 19:00:00")'

# 如果数据库连接失败，数据会自动保存到 save_after_error/ 目录
数据入库成功时显示 ✓，失败时自动保存到 save_after_error/ 目录
备份文件命名格式：{news_time}_top.txt / {news_time}_newest.txt