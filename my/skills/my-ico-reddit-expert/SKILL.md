---
model: opus
name: my-ico-reddit-expert
description: Reddit API expert for ICO Reddit Monitor. Covers unauthenticated API, rate limits, Listing objects, thing types, pagination, scraping patterns, relevance scoring, and operational best practices. Use when building or modifying Reddit scrapers, analysing Reddit data, or troubleshooting rate limit issues.
---

# Reddit Expert — ICO Reddit Monitor

Expert knowledge for Reddit's public JSON API, scraping patterns, rate limit management, and content classification for the ICO Reddit Monitor project.

## Reddit Public JSON API

### Endpoint Pattern

```
https://www.reddit.com/r/{subreddit}/{sort}.json?limit=100&raw_json=1&after={cursor}
```

| Sort | Endpoint | Use Case |
|------|----------|----------|
| `new` | `/r/{sub}/new.json` | Monitor newest posts (Phase 1) |
| `hot` | `/r/{sub}/hot.json` | Trending content discovery |
| `top` | `/r/{sub}/top.json?t=day` | Daily highlights (t=hour/day/week/month/year/all) |
| `rising` | `/r/{sub}/rising.json` | Early trend detection |

### Required Query Parameters

| Param | Value | Purpose |
|-------|-------|---------|
| `limit` | 1–100 | Posts per request (always use 100 for efficiency) |
| `raw_json` | 1 | Proper encoding of special characters (& → &, not &amp;amp;) |
| `after` | `t3_xxxxx` | Pagination cursor — fullname of last post from previous page |
| `before` | `t3_xxxxx` | Reverse pagination (rarely needed) |

### Authentication

**Unauthenticated (current ICO approach):**
- No OAuth required — public subreddit data only
- MUST include descriptive User-Agent header
- Rate limit: ~100 requests per 10 minutes (we use 50 conservatively)

```php
$userAgent = 'ICO-RedditMonitor/2.0 (Educational Research; Contact: info@ico-cert.org)';
```

**OAuth (if needed later):**
- Register app at https://www.reddit.com/prefs/apps
- Token endpoint: `https://www.reddit.com/api/v1/access_token`
- Use `https://oauth.reddit.com/` as base URL (not www.reddit.com)
- OAuth doubles rate limit to ~200 req/10 min

## Thing Types (Fullnames)

Reddit objects use type prefixes called "fullnames":

| Prefix | Type | Example | Description |
|--------|------|---------|-------------|
| `t1_` | Comment | `t1_abc1234` | A comment on a post |
| `t2_` | Account | `t2_abc1234` | A user account |
| `t3_` | Link/Post | `t3_abc1234` | A submission (self-post or link) |
| `t4_` | Message | `t4_abc1234` | A private message |
| `t5_` | Subreddit | `t5_abc1234` | A subreddit |
| `t6_` | Award | `t6_abc1234` | An award |

**Rule:** Pagination tokens (`after`/`before`) are always fullnames, not bare IDs. Use `t3_` prefix for post pagination.

## Listing Object Structure

Every Reddit API response wraps data in a Listing:

```json
{
  "kind": "Listing",
  "data": {
    "after": "t3_next_cursor",
    "before": null,
    "dist": 100,
    "children": [
      {
        "kind": "t3",
        "data": {
          "id": "1a2b3c",
          "name": "t3_1a2b3c",
          "title": "Post title",
          "selftext": "Body text (self-posts only)",
          "author": "username",
          "subreddit": "cybersecurity",
          "url": "https://external-link.com",
          "permalink": "/r/cybersecurity/comments/1a2b3c/post_title/",
          "domain": "external-link.com",
          "score": 123,
          "upvote_ratio": 0.95,
          "num_comments": 45,
          "created_utc": 1708012345,
          "is_self": true,
          "link_flair_text": "News",
          "over_18": false,
          "stickied": false,
          "distinguished": null
        }
      }
    ]
  }
}
```

### Key Fields for ICO Monitor

| Field | Type | Use |
|-------|------|-----|
| `name` | string | Fullname (`t3_xxx`) — use as unique ID and pagination token |
| `id` | string | Short ID — use for dedup in Redis sets |
| `title` + `selftext` | string | Input for relevance scoring |
| `score` | int | Community engagement signal |
| `upvote_ratio` | float | Quality signal (>0.9 = well received) |
| `num_comments` | int | Discussion depth signal |
| `created_utc` | int | Unix timestamp — for freshness sorting |
| `author` | string | `[deleted]` means removed; skip for analysis |
| `is_self` | bool | true = text post, false = link post |
| `link_flair_text` | string | Subreddit-assigned category (nullable) |

## Rate Limit Management

### Headers (Read from Every Response)

```
X-Ratelimit-Remaining: 47.0     # Requests left in current window
X-Ratelimit-Reset: 342          # Seconds until window resets
X-Ratelimit-Used: 3             # Requests used in current window
```

**Parse case-insensitively** — Reddit sometimes varies casing.

### Budget Strategy (ICO Pattern)

```
BUDGET_MAX           = 50   (half of Reddit's ~100)
BUDGET_WARN          = 10   (enter cautious mode)
BUDGET_ABORT         = 3    (stop immediately)
DELAY_NORMAL         = 4s
DELAY_CAUTIOUS       = 10s
DELAY_RECOVERY       = 30s  (after errors)
DELAY_BACKFILL_PAGE  = 8s   (between backfill pages)
COOLDOWN_DURATION    = 120s (after HTTP 429)
```

### Redis State for Rate Limiting

```
ico_reddit:rate_budget          SortedSet  Request timestamps (sliding window, 600s)
ico_reddit:cooldown_until       String     Unix timestamp — skip runs until this time
ico_reddit:last_429             String     Unix timestamp of last 429 response
ico_reddit:run_stats            Hash       {last_run, status, duration_seconds, new_posts, ...}
ico_reddit:seen:{subreddit}     Set        Post fullnames (24h TTL, dedup)
```

### Sliding Window Algorithm

```php
// Record request
$redis->zAdd('ico_reddit:rate_budget', microtime(true), microtime(true));

// Prune expired
$cutoff = microtime(true) - 600;
$redis->zRemRangeByScore('ico_reddit:rate_budget', '-inf', $cutoff);

// Count used
$used = $redis->zCard('ico_reddit:rate_budget');
$remaining = max(0, 50 - $used);
```

## Three-Phase Scraping Cycle

### Phase 1: Monitor (Newest Posts)

```
For each subreddit (ordered by priority ASC, last_monitored_at ASC):
  Skip if recently checked (within monitor_interval_min)
  GET /r/{sub}/new.json?limit=100&raw_json=1
  Parse children → INSERT OR UPDATE posts
  Add fullnames to Redis seen set (24h TTL)
  Log to scrape_log
  Update subreddit_config.last_monitored_at
  Sleep DELAY_NORMAL or DELAY_CAUTIOUS
```

### Phase 2: Backfill (Deeper Pagination)

```
Only if budget > BUDGET_ABORT after Phase 1
Max 2 pages per sub, 6 pages total per run
For each sub with backfill_done=0:
  GET /r/{sub}/new.json?limit=100&after={cursor}
  Check dup ratio: if >80% already seen → mark backfill_done=1
  Store cursor in subreddit_config.backfill_cursor
  Sleep DELAY_BACKFILL_PAGE
```

### Phase 3: Pre-Classify (No API Calls)

```
SELECT 500 posts WHERE agent_status='pending'
For each post:
  score = RelevancePrefilter.score(title, selftext, category)
  UPDATE agent_relevance, agent_tags, agent_status
  If score >= 0.2 → agent_status='pending' (for later agent processing)
  If score < 0.2 → agent_status='skipped'
```

## Relevance Scoring Patterns

### High Value (0.4 points each)

| Pattern | Tag |
|---------|-----|
| ISO/IEC 42001, ISO 42001 | iso-42001 |
| ISO 27001 | iso-27001 |
| ISO 27701 | iso-27701 |
| NIS2 / NIS-2 | nis2 |
| DORA regulation | dora |
| GDPR / DSGVO | gdpr |
| AI Management System / AIMS | aims |
| Personal?a? certification | personal-certification |
| Auditor certification | auditor-certification |
| Certification body/scheme/program | certification-body |
| Accreditation | accreditation |
| Compliance officer/manager/training | compliance-training |
| CISO | ciso |
| ISMS | isms |

### Medium Value (0.2 points each)

| Pattern | Tag |
|---------|-----|
| certification (general) | certification |
| cybersecurity training/course/bootcamp | cyber-training |
| security awareness | security-awareness |
| risk management/assessment | risk-management |
| audit(ing) | auditing |
| compliance (general) | compliance |
| AI governance/ethics/regulation/act | ai-governance |
| EU AI Act | eu-ai-act |
| CompTIA, CISSP, CISM, CISA | vendor-cert |
| penetration testing | pentest |
| SOC 2 | soc2 |
| BCM / business continuity | bcm |

### Scoring Rules

- Score = sum of matched pattern weights, capped at 1.0
- Category bonus: +0.05 for `security_compliance` subreddits
- Threshold: score >= 0.2 sends post to agent classification
- Tags: deduplicated array of all matched pattern keys

## Monitored Subreddits

| Subreddit | Category | Priority |
|-----------|----------|:--------:|
| cybersecurity | security_compliance | 1 |
| ISO27001 | security_compliance | 1 |
| ITManagers | security_compliance | 2 |
| cybersecurity_help | security_compliance | 2 |
| Cybersecurity101 | security_compliance | 3 |
| CyberSecurityAdvice | security_compliance | 3 |
| ITCareerQuestions | careers_certs | 1 |
| certifications | careers_certs | 1 |
| ExamTopics | careers_certs | 2 |
| Career | careers_certs | 3 |
| careerguidance | careers_certs | 3 |
| ArtificialInteligence | ai_aims | 1 |
| aiHub | ai_aims | 2 |
| Ethics | ai_aims | 3 |
| AIJobs | ai_aims | 3 |

Priority 1 = checked every run. Priority 3 = checked only when budget allows.

## HTTP Error Handling

| Code | Action |
|------|--------|
| 200 | Process normally |
| 403 | Forbidden — subreddit private/quarantined. Skip, log warning |
| 404 | Subreddit doesn't exist. Disable in config |
| 429 | Rate limited — set 2-min cooldown, skip rest of run |
| 500-503 | Reddit server error — sleep DELAY_RECOVERY, retry once |
| Timeout | After 30s — log error, continue to next sub |

## Database Schema (Quick Reference)

### posts

Primary key: `id` (VARCHAR 20, Reddit fullname `t3_xxx`)

Key columns: `subreddit`, `category`, `title`, `selftext`, `author`, `url`, `permalink`, `score`, `upvote_ratio`, `num_comments`, `created_utc`, `is_self`, `link_flair_text`, `domain`

Agent columns: `agent_status` (pending/processing/classified/skipped/error), `agent_relevance` (0.0-1.0), `agent_category`, `agent_tags` (JSON), `agent_summary`, `agent_action` (none/monitor/respond/flag_urgent)

### subreddit_config

Primary key: `subreddit` (VARCHAR 100)

Key columns: `category`, `priority` (1-3), `enabled`, `monitor_interval_min`, `last_monitored_at`, `backfill_cursor`, `backfill_done`

### scrape_log

Auto-increment `id`. Logs every API request: `subreddit`, `mode` (monitor/backfill), `posts_fetched`, `posts_new`, `http_status`, `rate_limit_remaining`, `duration_ms`

## Operational Best Practices

1. **Never exceed half the rate limit** — Reddit can lower limits without notice
2. **Always read X-Ratelimit headers** — they are the source of truth, not your local counter
3. **Dedup with Redis sets** — 24h TTL prevents memory growth, catches reposts
4. **Log every API call** — scrape_log is essential for debugging rate issues
5. **Respect 429 aggressively** — 2-min minimum cooldown, don't retry immediately
6. **User-Agent must be descriptive** — Reddit blocks generic/missing UAs
7. **Use `raw_json=1`** — prevents double-encoding issues with HTML entities
8. **Backfill conservatively** — high dup ratio (>80%) means you've caught up
9. **Priority ordering** — ensure high-value subs (ISO27001, cybersecurity) always get budget
10. **Lock file** — prevent overlapping cron runs with `/tmp/ico_reddit_scraper.lock`

## Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| Using bare ID instead of fullname for `after` | Always prefix with `t3_` |
| Not URL-encoding `after` parameter | Fullnames are alphanumeric, no encoding needed |
| Parsing `selftext_html` instead of `selftext` | Use `selftext` (plain text) with `raw_json=1` |
| Ignoring `[deleted]` authors | Skip or mark — no useful content |
| Storing `score` as immutable | Scores change — UPDATE on re-fetch |
| Assuming `after=null` means error | `after=null` means last page reached |
| Running without User-Agent | Reddit returns 403 or 429 immediately |
| Trusting `dist` field for actual count | `dist` is approximate — count `children` array |
