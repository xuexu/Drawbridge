---
name: drawbridge-search
description: Use when current web search is needed through this drawbridge server. Call the configured HTTP search endpoint with a prompt and return the answer with source URLs.
---

# Drawbridge Search

Use this skill when the user asks for current web search, online lookup, recent information, or source-backed answers.

## Endpoint

POST http://127.0.0.1:8000/v1/search

Headers:

Authorization: Bearer <你的 CHATGPT2API_AUTH_KEY>
Content-Type: application/json

把上面尖括号里的内容换成你自己设置的密钥。不要在这个文件里写死真实密钥——
它会随仓库一起公开。

Body:

{
  "prompt": "<search question>"
}

## Response

Use `answer` as the main response. Include URLs from `sources` when available.
