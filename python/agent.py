import json
import re
import subprocess
from pathlib import Path

from extension import MCPManager
from provider import Provider

WORKDIR = Path.cwd()


# Agent's Toolkits
def safe_path(subpath: str) -> Path:
    path = (WORKDIR / subpath).resolve()
    if not path.is_relative_to(WORKDIR):
        raise ValueError(f"Path escapes workspace: {subpath}")
    return path


def run_bash(command: str) -> str:
    dangerous = ["rm -rf /", "sudo", "shutdown", "reboot", "> /dev/"]
    if any(d in command for d in dangerous):
        return "Error: Dangerous command blocked"
    try:
        r = subprocess.run(
            command,
            shell=True,
            cwd=WORKDIR,
            capture_output=True,
            text=False,  # Read as bytes to handle encoding manually
            timeout=120,
        )
        # Decode both stdout and stderr using utf-8 with replacement for invalid chars
        stdout = r.stdout.decode("utf-8", errors="replace")
        stderr = r.stderr.decode("utf-8", errors="replace")
        out = (stdout + stderr).strip()
        return out[:50000] if out else "(no output)"
    except subprocess.TimeoutExpired:
        return "Error: Timeout (120s)"


def run_read(path: str, max_line: int = -1) -> str:
    try:
        # Use utf-8 with errors='replace' for robustness on Windows/mixed encodings
        lines = (
            safe_path(path).read_text(encoding="utf-8", errors="replace").splitlines()
        )
        if max_line != -1 and max_line < len(lines):
            lines = lines[:max_line] + [f"... ({len(lines) - max_line} more)"]
        return "\n".join(lines)[:50000]
    except Exception as e:
        return f"Error: {e}"


def run_write(path: str, content: str) -> str:
    try:
        fp = safe_path(path)
        fp.parent.mkdir(parents=True, exist_ok=True)
        fp.write_text(content, encoding="utf-8", errors="replace")
        return f"Wrote {len(content)} bytes to {path}"
    except Exception as e:
        return f"Error: {e}"


def run_edit(path: str, old_text: str, new_text: str) -> str:
    try:
        fp = safe_path(path)
        c = fp.read_text(encoding="utf-8", errors="replace")
        if old_text not in c:
            return f"Error: Text not found in {path}"
        fp.write_text(
            c.replace(old_text, new_text, 1), encoding="utf-8", errors="replace"
        )
        return f"Edited {path}"
    except Exception as e:
        return f"Error: {e}"


TOOLS_DESCRIPTION = """
To perform actions, you MUST use the following format:
```tool
{
  "tool": "tool_name",
  "arguments": { "arg1": "val1" }
}
```

Available tools:
- bash(command: str): Run a shell command.
- read_file(path: str, max_line: int = -1): Read file contents.
- write_file(path: str, content: str): Write content to file.
- edit_file(path: str, old_text: str, new_text: str): Replace exact text in file.

If you are providing a JSON example for the user, use standard ```json blocks. Only use ```tool for actual execution.
"""


class Agent:
    def __init__(self, provider: Provider):
        self.provider = provider
        self.mcp_manager = MCPManager()
        self.tools = {
            "bash": run_bash,
            "read_file": run_read,
            "write_file": run_write,
            "edit_file": run_edit,
        }

    def _get_system_prompt(self) -> str:
        mcp_tools = self.mcp_manager.get_tools_schema()
        mcp_desc = ""
        if mcp_tools:
            mcp_desc = "\nAdditional MCP tools:\n" + json.dumps(mcp_tools, indent=2)
        return f"You are a coding agent at {WORKDIR}. {TOOLS_DESCRIPTION}{mcp_desc}\nAlways use the specified ```tool format for tool calls. Finish with a final answer."

    def act(self, messages: list):
        system_msg = {"role": "system", "content": self._get_system_prompt()}
        if not messages or messages[0].get("role") != "system":
            messages.insert(0, system_msg)
        elif messages[0].get("role") == "system":
            messages[0]["content"] = (
                system_msg["content"] + "\n\n" + messages[0]["content"]
            )

        for _ in range(10):
            response = self.provider.send(messages)
            messages.append({"role": "assistant", "content": response})
            yield {"type": "assistant", "content": response}

            # 使用更具体的 ```tool 标签，并增加对 ```json 的容错（带结构检查）
            tool_calls = re.findall(
                r"```(?:tool|json)\n(.*?)\n```", response, re.DOTALL
            )
            if not tool_calls:
                break

            results = []
            executed_any = False
            for call_str in tool_calls:
                try:
                    call: dict = json.loads(call_str)
                    if not isinstance(call, dict) or "tool" not in call:
                        continue

                    tool_name: str = call.get("tool")  # type: ignore
                    args = call.get("arguments", {})

                    if tool_name in self.tools:
                        output = self.tools[tool_name](**args)
                    else:
                        output = self.mcp_manager.execute(tool_name, **args)

                    yield {"type": "tool_result", "tool": tool_name, "output": output}
                    results.append(f"Tool '{tool_name}' output: {output}")
                    executed_any = True
                except Exception:
                    # 如果解析失败，说明不是规范的工具调用，可能只是普通的文本代码块
                    continue

            if not executed_any:
                break

            messages.append({"role": "user", "content": "\n".join(results)})

    @staticmethod
    def pretty(step: dict) -> str:
        """Beautify the execution steps for UI display."""
        stype = step.get("type")
        if stype == "assistant":
            content = step.get("content", "")

            def replace_with_placeholder(match):
                try:
                    # 尝试解析 JSON 以提取工具名
                    call = json.loads(match.group(1))
                    tool_name = call.get("tool", "unknown")
                    return f"\n\n> ⏳ **Calling tool: {tool_name}**...\n"
                except Exception:
                    # 如果解析失败（可能是 LLM 还没写完），显示通用占位符
                    return "\n\n> ⏳ **Calling tool**...\n"

            # 将工具块替换为醒目的占位符
            clean_content = re.sub(
                r"```(?:tool|json)\n(.*?)\n```",
                replace_with_placeholder,
                content,
                flags=re.DOTALL,
            ).strip()
            return clean_content
        elif stype == "tool_result":
            tool = step.get("tool")
            output = step.get("output", "")

            # 为 UI 保持简洁，如果是读取文件则仅显示前 3 行
            if tool == "read_file":
                lines = output.splitlines()
                if len(lines) > 3:
                    output = (
                        "\n".join(lines[:3]) + f"\n... ({len(lines) - 3} more lines)"
                    )
            elif tool == "bash":
                lines = output.splitlines()
                if len(lines) > 4:
                    output = f"... ({len(lines) - 4} earlier lines)\n" + "\n".join(
                        lines[-4:]
                    )

            # 使用醒目的样式标识工具执行结果
            return f"\n\n> 🛠️  **Executed {tool}**\n```\n{output}\n```\n"
        return ""
