# Error Contract

V1 errors use:

```json
{
  "success": false,
  "error": {
    "code": "POST_NOT_FOUND",
    "message": "The requested post does not exist.",
    "details": {}
  },
  "meta": {
    "requestId": "request-id"
  }
}
```

The API does not expose raw SQL errors, stack traces, secrets, provider keys or ranking internals.
