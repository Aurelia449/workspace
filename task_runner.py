"""
任务轮询执行器（Heartbeat）

依赖安装（在终端执行）：
pip install supabase python-dotenv

环境变量（建议放在 .env 文件里）：
- SUPABASE_URL
- SUPABASE_KEY
"""

from __future__ import annotations

import os
import time
import subprocess
from typing import Any, Dict, Optional

from supabase import Client, create_client

try:
    from dotenv import load_dotenv  # type: ignore
except Exception:  # pragma: no cover
    load_dotenv = None  # type: ignore


POLL_INTERVAL_SECONDS = 5


def _load_env() -> None:
    if load_dotenv is not None:
        load_dotenv()


def _get_supabase_client() -> Client:
    supabase_url = os.getenv("SUPABASE_URL", "")
    supabase_key = os.getenv("SUPABASE_KEY", "")

    if not supabase_url or not supabase_key:
        raise RuntimeError("缺少环境变量 SUPABASE_URL / SUPABASE_KEY（建议放在 .env 文件里）。")

    return create_client(supabase_url, supabase_key)


def _fetch_one_pending_task(supabase: Client) -> Optional[Dict[str, Any]]:
    # 优先按 created_at（若存在）取最早一条；否则退化为按 id
    resp = (
        supabase.table("tasks")
        .select("id, raw_prompt, status, created_at")
        .eq("status", "pending")
        .order("created_at", desc=False)
        .limit(1)
        .execute()
    )
    data = resp.data or []
    if data:
        return data[0]

    resp2 = (
        supabase.table("tasks")
        .select("id, raw_prompt, status")
        .eq("status", "pending")
        .order("id", desc=False)
        .limit(1)
        .execute()
    )
    data2 = resp2.data or []
    return data2[0] if data2 else None


def _try_claim_task(supabase: Client, task_id: Any) -> bool:
    # 通过“带条件的 update”实现抢占：只有 status 仍为 pending 才能改为 running
    resp = (
        supabase.table("tasks")
        .update({"status": "running"})
        .eq("id", task_id)
        .eq("status", "pending")
        .execute()
    )
    updated = resp.data or []
    return len(updated) > 0


def _set_status(supabase: Client, task_id: Any, status: str) -> None:
    supabase.table("tasks").update({"status": status}).eq("id", task_id).execute()


def _run_openclaw(raw_prompt: str) -> int:
    # 强制在“当前脚本所在目录”执行，避免 OpenClaw 把工作区写到用户目录下
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)

    forced_prefix = "【系统强制指令：请直接在当前工作目录下创建文件，不要使用任何虚拟空间或 Canvas 工具。】 "
    prompt = forced_prefix + raw_prompt

    # Windows 兼容版：使用 npx.cmd，并强制 shell=True
    # 注意：这里用双引号包住 -m 参数，需要转义其中的双引号，避免命令行参数被截断
    safe_prompt = prompt.replace('"', '\\"')
    cmd = f'npx.cmd openclaw agent --agent main -m "{safe_prompt}"'
    completed = subprocess.run(cmd, shell=True, check=False, cwd=script_dir)
    return completed.returncode


def main() -> None:
    _load_env()
    supabase = _get_supabase_client()

    print(f"Task runner started. Heartbeat every {POLL_INTERVAL_SECONDS}s.")

    while True:
        try:
            print("心跳中... 检查新任务...")
            task = _fetch_one_pending_task(supabase)
            if not task:
                time.sleep(POLL_INTERVAL_SECONDS)
                continue

            task_id = task.get("id")
            raw_prompt = (task.get("raw_prompt") or "").strip()

            if not task_id:
                print("发现一条 pending 任务但缺少 id，跳过。")
                time.sleep(POLL_INTERVAL_SECONDS)
                continue

            if not raw_prompt:
                print(f"任务 {task_id} raw_prompt 为空，标记为 failed。")
                _set_status(supabase, task_id, "failed")
                time.sleep(POLL_INTERVAL_SECONDS)
                continue

            claimed = _try_claim_task(supabase, task_id)
            if not claimed:
                # 可能被其他 runner 抢走了
                print(f"任务 {task_id} 抢占失败（可能已被抢走），继续心跳。")
                time.sleep(0.5)
                continue

            print(f"正在为任务 {task_id} 生成代码，需求是：{raw_prompt}")
            rc = _run_openclaw(raw_prompt)

            if rc == 0:
                _set_status(supabase, task_id, "success")
                print(f"任务 {task_id} 执行成功，已更新为 success。")
            else:
                _set_status(supabase, task_id, "failed")
                print(f"任务 {task_id} 执行失败（exit code={rc}），已更新为 failed。")

        except KeyboardInterrupt:
            print("收到 Ctrl+C，退出。")
            return
        except Exception as e:
            print(f"心跳异常：{e}")
        finally:
            time.sleep(POLL_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
