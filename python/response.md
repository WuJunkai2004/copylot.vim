# channel message

## copylot's stdin
use like this to send a message:
```
Content-Length: 82
{"action": "query", "content": [{"role":"user", "content":"Hello, how are you?"}]}
```

### action: query
```json
{
  "action": "query",
  "content": [
    {
      "role": "user",
      "content": "Hello, how are you?"
    }
  ]
}
```

### action: stop
```json
{
  "action": "stop",
  "content": []
}
```

### action: commit_message
```json
{
  "action": "commit_message",
  "content": []
}
```


## copylot's stdout
use like this to chat:
```
Content-Length: 28
{"type":"ends","content":""}
```

### type: answer
```json
{
  "type": "answer",
  "content": "这是一个测试消息。"
}
```

### type: ends
```json
{
  "type": "ends",
  "content": ""
}
```

### type: error
```json
{
  "type": "error",
  "content": "发生了一个错误。"
}
```