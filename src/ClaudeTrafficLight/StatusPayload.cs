using System;
using System.Text.Json.Serialization;

namespace ClaudeTrafficLight;

internal sealed class StatusPayload
{
    [JsonPropertyName("state")]
    public string? State { get; set; }

    [JsonPropertyName("time")]
    public DateTimeOffset? Time { get; set; }

    [JsonPropertyName("session_id")]
    public string? SessionId { get; set; }

    [JsonPropertyName("cwd")]
    public string? CurrentDirectory { get; set; }

    [JsonPropertyName("hook_event_name")]
    public string? HookEventName { get; set; }

    [JsonPropertyName("tool_name")]
    public string? ToolName { get; set; }

    [JsonPropertyName("notification_type")]
    public string? NotificationType { get; set; }

    [JsonPropertyName("source")]
    public string? Source { get; set; }
}
