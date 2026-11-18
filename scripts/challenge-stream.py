#!/usr/bin/env python3
"""Pretty-print π --mode json events to the terminal (stdin = JSONL)."""
from __future__ import annotations

import json
import sys


def short(s: str, n: int = 160) -> str:
    s = " ".join((s or "").split())
    return s if len(s) <= n else s[: n - 1] + "…"


def args_preview(args) -> str:
    if not isinstance(args, dict):
        return short(str(args))
    for k in ("command", "path", "file_path", "pattern", "query", "content"):
        if k in args and args[k] is not None:
            v = args[k]
            if k == "content":
                return f"{k}={short(str(v), 80)} ({len(str(v))} chars)"
            return f"{k}={short(str(v), 120)}"
    return short(json.dumps(args, ensure_ascii=False), 120)


def result_preview(result) -> str:
    if result is None:
        return ""
    if isinstance(result, dict):
        parts = result.get("content") or []
        texts = []
        for p in parts:
            if isinstance(p, dict) and p.get("type") == "text":
                texts.append(p.get("text") or "")
        if texts:
            return short("\n".join(texts), 200)
        return short(json.dumps(result, ensure_ascii=False), 120)
    return short(str(result), 200)


def main() -> None:
    turn = 0
    in_text = False

    for raw in sys.stdin:
        line = raw.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            print(f"! bad json: {short(line)}", flush=True)
            continue
        t = ev.get("type")

        if t == "session":
            print(f"[session] cwd={ev.get('cwd')} id={ev.get('id')}", flush=True)
        elif t == "agent_start":
            print("[agent] start", flush=True)
        elif t == "turn_start":
            turn += 1
            print(f"\n--- turn {turn} ---", flush=True)
        elif t == "message_update":
            ame = ev.get("assistantMessageEvent") or {}
            at = ame.get("type")
            if at == "text_delta":
                if not in_text:
                    sys.stdout.write("assistant> ")
                    in_text = True
                sys.stdout.write(ame.get("delta") or "")
                sys.stdout.flush()
            elif at == "text_end":
                if in_text:
                    print(flush=True)
                    in_text = False
            elif at == "toolcall_start":
                if in_text:
                    print(flush=True)
                    in_text = False
                print(f"  → planning {ame.get('toolName')} …", flush=True)
            elif at == "error":
                if in_text:
                    print(flush=True)
                    in_text = False
                print(
                    f"  ! stream error: {short(str(ame.get('error') or ame.get('reason')))}",
                    flush=True,
                )
        elif t == "tool_execution_start":
            if in_text:
                print(flush=True)
                in_text = False
            name = ev.get("toolName")
            print(f"  ▶ {name}({args_preview(ev.get('args'))})", flush=True)
        elif t == "tool_execution_end":
            name = ev.get("toolName")
            ms = ev.get("durationMs")
            err = ev.get("isError")
            flag = "ERR" if err else "ok"
            dur = f" {ms}ms" if ms is not None else ""
            preview = result_preview(ev.get("result"))
            extra = f" → {preview}" if preview else ""
            print(f"  ■ {name} [{flag}{dur}]{extra}", flush=True)
        elif t == "agent_end":
            if in_text:
                print(flush=True)
                in_text = False
            retry = ev.get("willRetry")
            print(f"[agent] end{' (will retry)' if retry else ''}", flush=True)
        elif t == "agent_settled":
            if in_text:
                print(flush=True)
                in_text = False
            aborted = ev.get("aborted")
            print(f"[agent] settled{' (aborted)' if aborted else ''}", flush=True)
        elif t == "error":
            print(f"[error] {short(json.dumps(ev, ensure_ascii=False))}", flush=True)


if __name__ == "__main__":
    main()
