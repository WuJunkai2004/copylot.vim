# python/provider.py
# A provider for the AI provider
import json
import urllib.request

from config import Config


def post(url: str, headers: dict, data: str, timeout: int = 60) -> tuple[str, str]:
    req = urllib.request.Request(url, headers=headers, data=data.encode("utf-8"))
    try:
        with urllib.request.urlopen(req, timeout=timeout) as res:
            return res.read().decode("utf-8"), ""
    except Exception as e:
        return "", str(e)


def get(url: str, headers: dict, timeout: int = 60) -> tuple[str, str]:
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as res:
            return res.read().decode("utf-8"), ""
    except Exception as e:
        return "", str(e)


class Stream:
    def __init__(self, url: str):
        self.url: str = url

    def post(self, headers: dict, data: str, timeout: int = 60):
        req = urllib.request.Request(
            self.url, headers=headers, data=data.encode("utf-8")
        )
        try:
            with urllib.request.urlopen(req, timeout=timeout) as res:
                for line in res:
                    yield line.decode("utf-8"), ""
        except Exception as e:
            yield "", str(e)

    def get(self, headers: dict, timeout: int = 60):
        req = urllib.request.Request(self.url, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=timeout) as res:
                for line in res:
                    yield line.decode("utf-8"), ""
        except Exception as e:
            yield "", str(e)


class Provider:
    def __init__(self, api_url, api_key, model):
        self.api_url: str = api_url
        self.api_key: str = api_key
        self.model: str = model

    def send(self, message) -> str:
        raise NotImplementedError("The send method must be implemented by subclasses")

    def stream(self, message):
        raise NotImplementedError("The stream method must be implemented by subclasses")


class OpenAIProvider(Provider):
    def __init__(self, api_url, api_key, model):
        super().__init__(api_url, api_key, model)
        if not self.api_url.endswith("/chat/completions"):
            if not self.api_url.endswith("/"):
                self.api_url += "/"
            if not self.api_url.endswith("v1/"):
                self.api_url += "v1/"
            self.api_url += "chat/completions"

    def send(self, message: list) -> str:
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
        }
        data = json.dumps(
            {
                "model": self.model,
                "messages": message,
                "stream": False,
            }
        )
        response, error = post(self.api_url, headers, data)
        if error:
            raise Exception(f"Error sending message: {error}")

        if response.startswith("data:"):
            response = response[5:].strip()
        try:
            response_json = json.loads(response)
            if "choices" in response_json and len(response_json["choices"]) > 0:
                return response_json["choices"][0]["message"]["content"]
            else:
                return ""
        except Exception as e:
            print(f"response: {response}")
            raise Exception(f"Error parsing response: {e}")

    def stream(self, message: list):
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
            "Accept": "text/event-stream",
        }
        data = json.dumps(
            {
                "model": self.model,
                "messages": message,
                "stream": True,
            }
        )
        for chunk, error in Stream(self.api_url).post(headers, data):
            if error:
                raise Exception(f"Error streaming message: {error}")
            for line in chunk.split("\n"):
                line = line.strip()
                if not line or not line.startswith("data:"):
                    continue
                payload = line[5:].strip()
                if payload == "[DONE]":
                    return
                try:
                    chunk_json = json.loads(payload)
                    if "choices" in chunk_json and len(chunk_json["choices"]) > 0:
                        delta = chunk_json["choices"][0].get("delta", {})
                        content = delta.get("content")
                        if content is not None:
                            yield content
                except json.JSONDecodeError:
                    continue


def ProviderBuild(path: str) -> Provider:
    setting = Config(path)
    if not setting.load_success:
        raise Exception("Error loading config")

    if not setting.required("provider"):
        raise Exception("provider is required in config")
    provider_name = setting.get("provider")

    if not setting.required([f"{provider_name}.api_url", f"{provider_name}.model"]):
        raise Exception("api_url and model are required in config")

    schema_name: str = setting.get(f"{provider_name}.schema", "openai")  # type: ignore

    sub_class_map = {sub.__name__.lower(): sub for sub in Provider.__subclasses__()}
    for sub_class in sub_class_map:
        if sub_class.startswith(schema_name):
            return sub_class_map[sub_class](
                setting.get(f"{provider_name}.api_url"),
                setting.get(f"{provider_name}.api_key", ""),
                setting.get(f"{provider_name}.model"),
            )

    return OpenAIProvider(
        setting.get(f"{provider_name}.api_url"),
        setting.get(f"{provider_name}.api_key", ""),
        setting.get(f"{provider_name}.model"),
    )
