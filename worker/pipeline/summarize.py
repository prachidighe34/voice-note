import requests

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

SYSTEM_PROMPT = (
    "You summarize voice note transcripts. Write a concise 1-2 sentence "
    "summary capturing the key point. Plain text only, no preamble like "
    "'Here is a summary' — just the summary itself."
)


class Summarizer:
    """Calls OpenRouter's OpenAI-compatible chat completions endpoint.

    OpenRouter's free models rotate over time (identified by a ":free"
    suffix on the model slug) — check https://openrouter.ai/models?max_price=0
    for what's currently available if OPENROUTER_MODEL stops working.
    """

    def __init__(self, api_key: str, model: str):
        self.api_key = api_key
        self.model = model

    def summarize(self, text: str) -> str:
        if not text.strip():
            return ""

        response = requests.post(
            OPENROUTER_URL,
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
                # Some providers require these to route/allow a request —
                # harmless to always send them.
                "HTTP-Referer": "https://github.com/voice-notes",
                "X-Title": "Voice Notes",
            },
            json={
                "model": self.model,
                "messages": [
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": text},
                ],
            },
            timeout=30,
        )

        if response.status_code >= 400:
            # Surface OpenRouter's actual error body instead of just the
            # generic status line — it names the real reason (policy,
            # guardrail, model-specific restriction, etc).
            raise RuntimeError(
                f"OpenRouter request failed ({response.status_code}): {response.text}"
            )

        body = response.json()
        try:
            return body["choices"][0]["message"]["content"].strip()
        except (KeyError, IndexError) as exc:
            raise RuntimeError(f"Unexpected OpenRouter response shape: {body}") from exc