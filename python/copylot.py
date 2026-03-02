import json
import os
import sys
import traceback

from .git import gitDiff, gitLog
from .provider import ProviderBuild


class CopyLotDaemon:
    def __init__(self, config_path: str | None = None):
        # Determine config path: Priority 1. Constructor 2. Default ~/.vim/ai_config.toml
        if (
            not config_path
            or not os.path.isfile(config_path)
            or not os.access(config_path, os.R_OK)
        ):
            config_path = os.path.expanduser("~/.vim/ai_config.toml")

        self.config_path = config_path
        self.provider = None
        try:
            self.provider = ProviderBuild(config_path)
        except Exception as e:
            self.log(f"Failed to initialize provider: {e}")

    def log(self, msg):
        sys.stderr.write(f"LOG: {msg}\n")
        sys.stderr.flush()

    def send_response(self, resp_type: str, content):
        """Sends a JSON response with Content-Length header."""
        # type: answer, ends, error, gitmsg
        response_obj = {"type": resp_type, "content": content}
        body = json.dumps(response_obj, ensure_ascii=False)
        encoded_body = body.encode("utf-8")
        header = f"Content-Length: {len(encoded_body)}\r\n\r\n"
        sys.stdout.buffer.write(header.encode("ascii") + encoded_body)
        sys.stdout.buffer.flush()

    def handle_query(self, content: list):
        """Handle 'query' action."""
        if not self.provider:
            self.send_response("error", "Provider not initialized. Check your config.")
            return

        # content is expected to be a list of messages: [{"role": "user", "content": "..."}]
        if not isinstance(content, list):
            self.send_response("error", "Content must be a list of messages.")
            return

        try:
            ai_res = self.provider.send(content)
            if ai_res is None:
                self.send_response("error", "AI returned None.")
            else:
                self.send_response("answer", ai_res)
        except Exception as e:
            self.send_response("error", f"AI Provider Error: {str(e)}")
        finally:
            self.send_response("ends", "")

    def handle_stop(self):
        """Handle 'stop' action."""
        # Placeholder for stopping current generation if streaming is implemented
        self.log("Stop requested (not fully implemented)")
        self.send_response("ends", "")

    def handle_commit_message(self):
        """Handle 'commit_message' action."""
        if not self.provider:
            self.send_response("error", "Provider not initialized.")
            return

        try:
            diff = gitDiff(cached=True)
            # Truncate diff if it's too long
            diff_lines = diff.splitlines()
            if len(diff_lines) > 200:
                diff = (
                    "\n".join(diff_lines[:200]) + "\n\n(Diff truncated for brevity...)"
                )

            history = gitLog(n=10)
            if not diff.strip() or diff.startswith("An error occurred"):
                self.send_response(
                    "answer", f"No staged changes found or error: {diff}"
                )
            else:
                prompt = (
                    f"The following is the user's recent commit history:\n"
                    f"{history}\n\n"
                    f"Please generate a concise git commit message for the following diff, "
                    f"imitating the user's style (e.g., prefix usage, tone, length):\n\n"
                    f"{diff}"
                )
                messages = [
                    {
                        "role": "system",
                        "content": "You are a git commit expert who mimics the user's specific writing style based on history.",
                    },
                    {"role": "user", "content": prompt},
                ]
                ai_res = self.provider.send(messages)
                self.send_response("gitmsg", ai_res)
        except Exception as e:
            self.send_response("error", f"Git Commit Error: {str(e)}")
        finally:
            self.send_response("ends", "")

    def handle_mcp(self, content):
        """Placeholder for Model Context Protocol (MCP) support."""
        # Future implementation for MCP
        self.log(f"MCP action received: {content}")
        self.send_response("error", "MCP support is not yet implemented.")
        self.send_response("ends", "")

    def dispatch(self, msg):
        """Dispatch message to appropriate handler based on 'action'."""
        action = msg.get("action")
        content = msg.get("content", [])

        if action == "query":
            self.handle_query(content)
        elif action == "stop":
            self.handle_stop()
        elif action == "commit_message":
            self.handle_commit_message()
        elif action == "mcp":
            self.handle_mcp(content)
        else:
            self.send_response("error", f"Unknown action: {action}")
            self.send_response("ends", "")

    def mainloop(self):
        while True:
            try:
                # Read Headers
                line = sys.stdin.readline()
                if not line:
                    break

                content_length = None
                if line.lower().startswith("content-length:"):
                    try:
                        content_length = int(line.split(":")[1].strip())
                    except ValueError:
                        pass

                # Consume remaining headers until empty line
                while line.strip():
                    line = sys.stdin.readline()
                    if not line:
                        break

                if content_length is None:
                    continue

                # Read Body
                body_data = sys.stdin.read(content_length)
                if not body_data:
                    break

                msg = json.loads(body_data)
                self.dispatch(msg)

            except EOFError:
                break
            except Exception as e:
                self.log(f"Mainloop Error: {traceback.format_exc()}")
                self.send_response("error", f"Internal Error: {str(e)}")


if __name__ == "__main__":
    config_path_arg = sys.argv[1] if len(sys.argv) > 1 else None
    daemon = CopyLotDaemon(config_path_arg)
    daemon.mainloop()
