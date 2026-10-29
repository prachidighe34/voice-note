from faster_whisper import WhisperModel


class Transcriber:
    def __init__(self, model_size: str = "base"):
        # compute_type="int8" keeps this usable on CPU without a GPU.
        self.model = WhisperModel(model_size, device="cpu", compute_type="int8")

    def transcribe(self, audio_path: str) -> str:
        segments, _info = self.model.transcribe(audio_path)
        return " ".join(segment.text.strip() for segment in segments).strip()
