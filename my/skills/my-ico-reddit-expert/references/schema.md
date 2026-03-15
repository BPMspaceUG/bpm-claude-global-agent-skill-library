# Database Schema (Quick Reference)

## posts

Primary key: `id` (VARCHAR 20, Reddit fullname `t3_xxx`)

Key columns: `subreddit`, `category`, `title`, `selftext`, `author`, `url`, `permalink`, `score`, `upvote_ratio`, `num_comments`, `created_utc`, `is_self`, `link_flair_text`, `domain`

Agent columns: `agent_status` (pending/processing/classified/skipped/error), `agent_relevance` (0.0-1.0), `agent_category`, `agent_tags` (JSON), `agent_summary`, `agent_action` (none/monitor/respond/flag_urgent)

## subreddit_config

Primary key: `subreddit` (VARCHAR 100)

Key columns: `category`, `priority` (1-3), `enabled`, `monitor_interval_min`, `last_monitored_at`, `backfill_cursor`, `backfill_done`

## scrape_log

Auto-increment `id`. Logs every API request: `subreddit`, `mode` (monitor/backfill), `posts_fetched`, `posts_new`, `http_status`, `rate_limit_remaining`, `duration_ms`
