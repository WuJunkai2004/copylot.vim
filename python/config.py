import os


def parse_toml(content: str):
    result = {}
    current_section = result
    for line in content.split("\n"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section_name = line[1:-1].strip()
            sections = section_name.split(".")
            for idx, sec in enumerate(sections):
                sec = sec.strip()
                if idx == 0:
                    current_section = result.setdefault(sec, {})
                else:
                    current_section = current_section.setdefault(sec, {})
        else:
            if "=" in line:
                key, value = line.split("=", 1)
                key = key.strip()
                value = value.strip().strip('"').strip("'")
                current_section[key] = value
    return result


class Config:
    def __init__(self, config_path: str):
        self.config_path = config_path
        self.load_success = bool(
            config_path
            and os.path.exists(config_path)
            and os.access(config_path, os.R_OK)
        )
        if self.load_success:
            with open(config_path, "r", encoding="utf-8") as f:
                self.config = parse_toml(f.read())

    def get(self, key: str, default=None):
        if not self.load_success:
            return None
        keys = key.split(".")
        value = self.config
        for k in keys:
            if not isinstance(value, dict):
                return default
            value = value.get(k)
            if value is None:
                return default
        return value

    def required(self, key):
        if isinstance(key, str):
            value = self.get(key)
            if value is None:
                return False
            return True
        elif isinstance(key, list):
            for k in key:
                if not self.required(k):
                    return False
            return True
        else:
            return False
