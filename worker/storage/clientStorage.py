import os
import tempfile

import requests


class SupabaseStorage:
    """Downloads audio objects from a private Supabase Storage bucket.

    The service_role key bypasses RLS/bucket privacy, so the worker can
    fetch objects directly without needing a signed URL from the Go server.
    """

    def __init__(self, base_url: str, service_key: str, bucket: str):
        self.base_url = base_url.rstrip("/")
        self.service_key = service_key
        self.bucket = bucket

    def download_to_tempfile(self, object_path: str) -> str:
        url = f"{self.base_url}/storage/v1/object/{self.bucket}/{object_path}"
        headers = {
            "Authorization": f"Bearer {self.service_key}",
            "apikey": self.service_key,
        }

        resp = requests.get(url, headers=headers, stream=True, timeout=60)
        resp.raise_for_status()

        suffix = os.path.splitext(object_path)[1] or ".webm"
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
        try:
            for chunk in resp.iter_content(chunk_size=8192):
                tmp.write(chunk)
        finally:
            tmp.close()

        return tmp.name
