import time

from deep_translator import GoogleTranslator


class Translator:
    """Wraps deep-translator's GoogleTranslator — uses Google Translate's
    public web endpoint, no API key required. Fine for a portfolio
    project's volume; for production use you'd want a paid API
    (Google Cloud Translate, DeepL) with proper rate limits and an SLA.

    Retries a few times with backoff on failures, since rate-limit
    errors are transient — a burst of testing can trip Google's
    unofficial "5 requests/second" throttle, which usually clears
    within seconds to minutes, not hours.
    """

    MAX_RETRIES = 3
    BACKOFF_SECONDS = 5  # doubles each retry: 5s, 10s, 20s

    def translate(self, text: str, target_language: str) -> str:
        if not text.strip():
            return ""

        last_error: Exception | None = None
        for attempt in range(self.MAX_RETRIES):
            try:
                translator = GoogleTranslator(source="auto", target=target_language)
                return translator.translate(text)
            except Exception as exc:
                last_error = exc
                is_last_attempt = attempt == self.MAX_RETRIES - 1
                if is_last_attempt:
                    break
                wait = self.BACKOFF_SECONDS * (2**attempt)
                print(f"[translate] attempt {attempt + 1} failed ({exc}); retrying in {wait}s")
                time.sleep(wait)

        raise last_error