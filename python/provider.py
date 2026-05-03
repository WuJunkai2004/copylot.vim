# python/provider.py
# A provider for the AI provider
import json
import os
import urllib.request


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


def __toml_loads(s: str) -> tuple[dict, str]:
    if not os.path.exists(s):
        return {}, f"File not found: {s}"
    result = {}
    with open(s, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            result[key] = value
    return result, ""


class Stream:
    def __init__(self, url: str):
        self.url: str = url

    def post(self, headers: dict, data: str, timeout: int = 60, sep="\n\n"):
        req = urllib.request.Request(
            self.url, headers=headers, data=data.encode("utf-8")
        )
        try:
            with urllib.request.urlopen(req, timeout=timeout) as res:
                buffer = ""
                while True:
                    chunk = res.read(1024).decode("utf-8")
                    if not chunk:
                        break
                    buffer += chunk
                    while sep in buffer:
                        part, buffer = buffer.split(sep, 1)
                        yield part, ""
                if buffer:
                    yield buffer, ""
        except Exception as e:
            yield "", str(e)

    def get(self, headers: dict, timeout: int = 60, sep="\n\n"):
        req = urllib.request.Request(self.url, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=timeout) as res:
                buffer = ""
                while True:
                    chunk = res.read(1024).decode("utf-8")
                    if not chunk:
                        break
                    buffer += chunk
                    while sep in buffer:
                        part, buffer = buffer.split(sep, 1)
                        yield part, ""
                if buffer:
                    yield buffer, ""
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
                        if "content" in delta:
                            yield delta["content"]
                except json.JSONDecodeError:
                    continue


def ProviderBuild(path: str) -> Provider:
    config, err = __toml_loads(path)
    if err:
        raise Exception(f"Error loading config: {err}")
    if "api_url" not in config:
        raise Exception("api_url is required in config")

    provider_name = config.get("provider", "openai").lower()
    default_provider = OpenAIProvider
    sub_class_map = {sub.__name__.lower(): sub for sub in Provider.__subclasses__()}
    for sub_class in sub_class_map:
        if sub_class.startswith(provider_name):
            return sub_class_map[sub_class](
                config["api_url"],
                config.get("api_key", ""),
                config.get("model", "gpt-3.5-turbo"),
            )

    return default_provider(
        config["api_url"],
        config.get("api_key", ""),
        config.get("model", "gpt-3.5-turbo"),
    )
