// Unity (C#) MultiPong WebSocket client — attach to a GameObject.
// Requires a WebSocket library. Recommended: NativeWebSocket (MIT) via OpenUPM/Git,
// or Unity 6+ ClientWebSocket patterns. This file shows the protocol + update loop;
// swap _Send/_Connect to your chosen socket wrapper.
//
// Canonical state uses top-left origin, Y-down. Convert when placing sprites:
//   unityY = playfieldHeight - canonicalY

using System;
using System.Collections.Generic;
using System.Text;
using UnityEngine;

[Serializable] public class MpBall { public float x, y, vx, vy; public bool active; }
[Serializable] public class MpPlayer { public float y; public int score; }
[Serializable] public class MpState
{
    public string mode;
    public int tick;
    public float elapsed_time;
    public float point_pause_remaining;
    public string mode_before_pause;
    public MpBall ball;
    public MpPlayer player1;
    public MpPlayer player2;
    public int serving_player;
    public int winner;
}

[Serializable] public class MpEnvelope
{
    public string type;
    public int player;
    public int you;
    public string room;
    public string message;
    public string name;
    public int protocol;
    public MpState state;
}

public class MultiPongClient : MonoBehaviour
{
    public string serverUrl = "ws://127.0.0.1:8765";
    public string room = "demo";
    public string playerName = "unity";

    public MpState State { get; private set; }
    public int Seat { get; private set; }

    readonly HashSet<string> _held = new();
    readonly List<string> _pressed = new();

    // Replace with NativeWebSocket.WebSocket or System.Net.WebSockets
    object _socket;
    bool _joined;

    void Update()
    {
        _held.Clear();
        if (Input.GetKey(KeyCode.W) || Input.GetKey(KeyCode.UpArrow)) _held.Add("UP");
        if (Input.GetKey(KeyCode.S) || Input.GetKey(KeyCode.DownArrow)) _held.Add("DOWN");
        if (Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.Space)) _pressed.Add("CONFIRM");
        if (Input.GetKeyDown(KeyCode.P) || Input.GetKeyDown(KeyCode.Escape)) _pressed.Add("PAUSE");
        if (Input.GetKeyDown(KeyCode.R)) _pressed.Add("RESTART");

        // DispatchInput(); // send JSON each frame once connected
        // Render from State using canonical sizes from specs/pong/constants.json
    }

    public string BuildJoinJson()
    {
        return JsonUtility.ToJson(new JoinMsg { type = "join", room = room, name = playerName });
    }

    public string BuildInputJson()
    {
        var held = new List<string>(_held);
        var pressed = new List<string>(_pressed);
        _pressed.Clear();
        return "{\"type\":\"input\",\"held\":[" + QuoteList(held) + "],\"pressed\":[" + QuoteList(pressed) + "]}";
    }

    public void OnMessage(string json)
    {
        var msg = JsonUtility.FromJson<MpEnvelope>(json);
        if (msg.type == "welcome") Seat = msg.player;
        else if (msg.type == "state")
        {
            State = msg.state;
            if (msg.you != 0) Seat = msg.you;
        }
        else if (msg.type == "error") Debug.LogError(msg.message);
    }

    static string QuoteList(List<string> items)
    {
        var sb = new StringBuilder();
        for (int i = 0; i < items.Count; i++)
        {
            if (i > 0) sb.Append(',');
            sb.Append('"').Append(items[i]).Append('"');
        }
        return sb.ToString();
    }

    [Serializable] class JoinMsg { public string type; public string room; public string name; }
}
