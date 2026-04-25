"""
Telegram 任务接收后端

依赖安装（在终端执行）：
pip install pyTelegramBotAPI supabase
"""

import os
import telebot
from supabase import create_client, Client


# =========================
# 请在这里填写你的配置
# =========================
TG_BOT_TOKEN = os.getenv("TG_BOT_TOKEN", "YOUR_TELEGRAM_BOT_TOKEN")
SUPABASE_URL = os.getenv("SUPABASE_URL", "YOUR_SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "YOUR_SUPABASE_KEY")

if (
    TG_BOT_TOKEN in ("", "YOUR_TELEGRAM_BOT_TOKEN")
    or SUPABASE_URL in ("", "YOUR_SUPABASE_URL")
    or SUPABASE_KEY in ("", "YOUR_SUPABASE_KEY")
):
    raise RuntimeError(
        "请先配置 TG_BOT_TOKEN / SUPABASE_URL / SUPABASE_KEY。"
        "建议通过环境变量设置，避免把密钥写进代码仓库。"
    )


bot = telebot.TeleBot(TG_BOT_TOKEN)
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)


@bot.message_handler(commands=["newtask"])
def handle_newtask(message):
    # 解析 /newtask 后面的需求文本
    parts = message.text.split(maxsplit=1) if message.text else []
    raw_prompt = parts[1].strip() if len(parts) > 1 else ""

    if not raw_prompt:
        bot.reply_to(message, "请在 /newtask 后输入具体需求，例如：/newtask 做一个企业官网首页")
        return

    payload = {
        "task_type": "website_generation",
        "raw_prompt": raw_prompt,
        "status": "pending",
    }

    try:
        supabase.table("tasks").insert(payload).execute()
        bot.reply_to(message, "✅ 任务已成功入库！状态: pending。等待 OpenClaw 执行。")
    except Exception as e:
        bot.reply_to(message, f"❌ 入库失败：{e}")


if __name__ == "__main__":
    print("Bot is running... Press Ctrl+C to stop.")
    bot.infinity_polling()
