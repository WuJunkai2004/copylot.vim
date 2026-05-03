# Copylot Vim

Copylot is an AI-powered programming assistant for Vim. It provides a chat sidebar for interacting with AI models and an autonomous agent that can perform tasks like running shell commands and editing files directly within your workspace.

Copylot 是一个为 Vim 打造的 AI 编程助手。它提供了一个聊天侧边栏，用于与 AI 模型交互，并包含一个能够执行 Shell 命令和直接编辑工作区文件的自主智能体（Agent）。

## Features / 功能特性

- **AI Chat Sidebar**: Interact with AI models in a dedicated sidebar.
- **Autonomous Agent**: Trigger an agent using `@agent` to perform complex tasks (Bash, File I/O, MCP).
- **Git Integration**: Generate concise and idiomatic commit messages based on your staged changes.
- **Customizable Backend**: Support for OpenAI-compatible APIs (OpenAI, DeepSeek, local LLMs, etc.).

- **AI 聊天侧边栏**：在专用的侧边栏中与 AI 模型对话。
- **自主智能体**：在聊天中使用 `@agent` 触发智能体，执行复杂任务（Bash、文件读写、MCP）。
- **Git 集成**：根据暂存区（staged）的差异自动生成简洁且符合你风格的提交信息。
- **可自定义后端**：支持所有兼容 OpenAI 接口的 API（OpenAI, DeepSeek, 本地模型等）。

## Installation / 安装

### Dependencies / 依赖

- **Vim** >= 9.0 (with `+job`, `+channel`, `+json`).
- **Python** 3.8+.

### Using Plugin Manager / 使用插件管理器

```vim
" vim-plug
Plug 'fittentech/fittencode.vim'

" vundle
Plugin 'fittentech/fittencode.vim'
```

## Configuration / 配置

Copylot requires a configuration file to connect to your AI provider. By default, it looks for `~/.vim/ai_config.toml`.

Copylot 需要一个配置文件来连接 AI 服务提供商。默认情况下，它会读取 `~/.vim/ai_config.toml`。

### `~/.vim/ai_config.toml` Example / 示例

```toml
api_url = "https://api.openai.com/v1"
api_key = "your-api-key-here"
model = "gpt-4o"
# provider = "openai" # optional
```

### Vim Options / Vim 选项

| Option | Description | Default |
| :--- | :--- | :--- |
| `g:copylot_config` | Path to the config file. | `~/.vim/ai_config.toml` |
| `g:copylot_history` | Number of chat messages to keep in history. | `20` |

## Usage / 使用方法

### Commands / 命令

- `:CopylotChat`: Toggle the AI Chat sidebar. / 打开或关闭 AI 聊天侧边栏。
- `:CopylotCommit`: Generate a Git commit message based on staged changes. / 根据暂存区的改动生成 Git 提交信息。

### AI Chat & Agent / 聊天与智能体

In the Chat sidebar, you can interact with the AI:
- Press **`q`** to start typing a question.
- Press **Enter twice** to submit your question.
- Press **`h`** to show the help message.
- Click **`[copy]`** or **`[apply]`** (or press Enter on them) in code blocks to copy code or apply it directly to your previous window.

To invoke the autonomous agent, include **`@agent`** in your message.

在聊天侧边栏中，你可以与 AI 交互：
- 按下 **`q`** 开始输入问题。
- **连按两次回车** 提交问题。
- 按下 **`h`** 显示帮助信息。
- 点击代码块旁边的 **`[copy]`** 或 **`[apply]`**（或在上面按回车）来复制代码或将其直接应用到上一个窗口。

若要调用自主智能体，请在消息中包含 **`@agent`**。

**Example / 示例:**
> `@agent Help me find all TODOs in the src directory and summarize them.`

The agent has access to:
- `bash`: Run shell commands.
- `read_file`: Read file contents.
- `write_file`: Create or overwrite files.
- `edit_file`: Replace text in files.

## License

MIT
