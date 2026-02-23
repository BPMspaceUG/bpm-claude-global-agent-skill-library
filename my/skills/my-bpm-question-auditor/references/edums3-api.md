# EduMS3 API Reference — Question Auditor

EduMS3 uses [php-crud-api](https://github.com/mevdschee/php-crud-api) as its REST backend.

## Environment Variables

```bash
source .env  # or ~/.config/cac/.env
# Provides:
# - EduMS3_Hostname_RO_API  (e.g., https://api.example.com/)
# - EduMS3_HostnameToken_RO_API  (Base64-encoded Basic auth credentials)
```

## Authentication

All requests use HTTP Basic Auth:

```bash
--header "Authorization: Basic ${EduMS3_HostnameToken_RO_API}"
```

## CLI Flag to API Filter Mapping

| CLI Flag | API Filters | Effect |
|----------|-------------|--------|
| `--all` (default) | `filter=deleted_at,nl` | All non-deleted questions |
| `--published` | `filter=published_at,nnl&filter=deleted_at,nl` | Only published, non-deleted |
| `--unpublished` | `filter=published_at,nl&filter=deleted_at,nl` | Only unpublished, non-deleted |

All modes always exclude soft-deleted questions (`deleted_at,nl`).

## Fetching Questions for a Topic

### `--all`: All questions (excluding soft-deleted)

```bash
curl -s --location "${EduMS3_Hostname_RO_API}records/questions?join=answers&filter=topic_uuid,eq,${TOPIC_UUID}&filter=deleted_at,nl" \
  --header "Authorization: Basic ${EduMS3_HostnameToken_RO_API}" | jq .
```

### `--published`: Only published questions

```bash
curl -s --location "${EduMS3_Hostname_RO_API}records/questions?join=answers&filter=topic_uuid,eq,${TOPIC_UUID}&filter=published_at,nnl&filter=deleted_at,nl" \
  --header "Authorization: Basic ${EduMS3_HostnameToken_RO_API}" | jq .
```

### `--unpublished`: Only unpublished questions

```bash
curl -s --location "${EduMS3_Hostname_RO_API}records/questions?join=answers&filter=topic_uuid,eq,${TOPIC_UUID}&filter=published_at,nl&filter=deleted_at,nl" \
  --header "Authorization: Basic ${EduMS3_HostnameToken_RO_API}" | jq .
```

## php-crud-api Filter Syntax

| Operator | Meaning | Example |
|----------|---------|---------|
| `eq` | Equals | `filter=topic_uuid,eq,<UUID>` |
| `nl` | Is NULL | `filter=deleted_at,nl` |
| `nnl` | Is NOT NULL | `filter=published_at,nnl` |

## Response Structure

```json
{
  "records": [
    {
      "uuid": "question-uuid-here",
      "id": 12345,
      "topic_uuid": "topic-uuid-here",
      "text": {
        "de": "German question text",
        "en": "English question text"
      },
      "published_at": "2026-01-15 10:00:00",
      "deleted_at": null,
      "answers": [
        {
          "uuid": "answer-uuid-here",
          "id": 54321,
          "text": {
            "de": "German answer text",
            "en": "English answer text"
          },
          "is_correct": true
        },
        {
          "uuid": "answer-uuid-2",
          "id": 54322,
          "text": {
            "de": "German wrong answer",
            "en": "English wrong answer"
          },
          "is_correct": false
        }
      ]
    }
  ]
}
```

**NOTE:** The `answers` field may be returned as an integer-keyed JSON object
(`{"0": {...}, "1": {...}}`) instead of a proper array (`[{...}, {...}]`).
If detected, flag this as a CRITICAL structural finding but still process
the answers by iterating over the object values.

## Optional: Syllabus Context Lookup

To determine certification level (Foundation vs Professional), fetch the
syllabus data that contains the topic:

```bash
# Step 1: Find syllabi containing this topic
curl -s --location "${EduMS3_Hostname_RO_API}records/syllabi?filter=topic_uuid,eq,${TOPIC_UUID}" \
  --header "Authorization: Basic ${EduMS3_HostnameToken_RO_API}" | jq .

# Step 2: From syllabus, get certificate info
curl -s --location "${EduMS3_Hostname_RO_API}records/syllabi/${SYLLABUS_UUID}?join=certificates" \
  --header "Authorization: Basic ${EduMS3_HostnameToken_RO_API}" | jq .
```

The certificate name or type indicates the level:
- Contains "FND" or "Foundation" → Foundation level (3 answer choices, easier)
- Contains "PRO" or "Professional" → Professional level (4 answer choices, harder)

## Domain Terms (Keep in English in German Text)

These terms are standard in both languages and should NOT be flagged as
translation issues when they appear in German text:

Stakeholder, Change Management, Service Level Agreement, Governance,
Compliance, Framework, Best Practice, Audit, Assessment, Review,
DevOps, CI/CD, Pipeline, Deployment, Sprint, Scrum, Backlog,
Key Performance Indicator (KPI), Return on Investment (ROI),
Artificial Intelligence, Machine Learning, Deep Learning, Prompt,
Natural Language Processing, Large Language Model
