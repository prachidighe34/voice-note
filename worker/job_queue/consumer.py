import json

import redis


class JobConsumer:
    QUEUE_KEY = "transcription_jobs"

    def __init__(self, redis_url: str, block_timeout: int = 5):
        self.block_timeout = block_timeout
        # socket_timeout must exceed the BRPOP block_timeout, otherwise the
        # client's own socket read times out a moment before Redis replies
        # with "nothing arrived," raising redis.exceptions.TimeoutError
        # instead of BRPOP just returning None as intended.
        self.client = redis.from_url(redis_url, socket_timeout=block_timeout + 5)

    def next_job(self, timeout: int | None = None):
        """Blocks up to `timeout` seconds (defaults to block_timeout) waiting
        for a job. Returns the parsed job dict, or None if nothing arrived.
        """
        effective_timeout = timeout if timeout is not None else self.block_timeout
        try:
            result = self.client.brpop(self.QUEUE_KEY, timeout=effective_timeout)
        except redis.exceptions.TimeoutError:
            # Belt-and-suspenders: treat a socket timeout the same as "no
            # job arrived" rather than crashing the worker loop.
            return None
        if result is None:
            return None
        _key, payload = result
        return json.loads(payload)