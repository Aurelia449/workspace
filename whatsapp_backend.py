"""
Twilio WhatsApp Webhook：接收消息并写入 Supabase tasks 表。

依赖安装（在终端执行）：
pip install flask supabase python-dotenv

环境变量（与项目 .env 一致）：
- SUPABASE_URL
- SUPABASE_KEY

说明：插入字段与 bot_backend.py / task_runner.py 一致——task_type、raw_prompt、status。
若你在表里另有 title/content 列且需要写入，可在下方 payload 中按需追加键名。
"""

from __future__ import annotations

import os
from flask import Flask, Response, request
from supabase import Client, create_client

try:
    from dotenv import load_dotenv  # type: ignore
except Exception:  # pragma: no cover
    load_dotenv = None  # type: ignore

if load_dotenv is not None:
    load_dotenv()

app = Flask(__name__)

TWIML_OK = (
    '<Response>'
    '<Message>【AI 助手】收到任务！正通知 OpenClaw 进场写代码...</Message>'
    '</Response>'
)


def _strip_env(value: str | None) -> str:
    if not value:
        return ""
    return value.strip().strip('"')


def _get_supabase() -> Client:
    url = _strip_env(os.getenv("SUPABASE_URL"))
    key = _strip_env(os.getenv("SUPABASE_KEY"))
    if not url or not key:
        raise RuntimeError("缺少环境变量 SUPABASE_URL / SUPABASE_KEY（建议放在 .env）。")
    return create_client(url, key)


@app.route("/whatsapp", methods=["POST"])
def whatsapp() -> Response:
    body = request.values.get("Body") or ""
    full_text = body.strip()

    try:
        supabase = _get_supabase()
        # 与 bot_backend 相同列名，便于 task_runner 消费 raw_prompt
        supabase.table("tasks").insert(
            {
                "task_type": "website_generation",
                "raw_prompt": full_text,
                "status": "pending",
            }
        ).execute()
    except Exception as e:
        # 仍返回 TwiML，避免 Twilio 反复重试；可将错误记入日志
        err_xml = (
            "<Response><Message>"
            f"入库失败：{str(e).replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')}"
            "</Message></Response>"
        )
        return Response(err_xml, mimetype="text/xml", status=200)

    return Response(TWIML_OK, mimetype="text/xml", status=200)


if __name__ == "__main__":
    # 本地调试可用；公网需 Twilio 能访问的 HTTPS URL（如 ngrok）
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "5000")), debug=False)
