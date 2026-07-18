"""
mitmproxy addon：被動側錄 Claude 桌面 App 對 /v1/messages 的真實回應，
把 anthropic-ratelimit-unified-* header 換算後寫進與 capture.sh 相同格式的
高水位目錄（~/.claude/cc-page/limit-5h.d / limit-7d.d），讓 overlay.swift
不須修改就能讀到桌面端更新的額度。

不主動發送任何請求，只側錄桌面 App 本來就會產生的流量，不消耗額外額度。
"""
import os
import time

CC_PAGE = os.path.expanduser("~/.claude/cc-page")
CEILING = {"5h": 6 * 3600, "7d": 8 * 86400}


def rl_sample(store_dir: str, window: str, pct: float, reset_epoch: float) -> None:
    now = time.time()
    if reset_epoch <= 0 or reset_epoch > now + CEILING[window]:
        return  # 拒絕不合理的未來 resets_at（sentinel/壞資料）
    os.makedirs(store_dir, exist_ok=True)
    entry = f"{int(reset_epoch):010d}_{pct:07.3f}"
    try:
        os.mkdir(os.path.join(store_dir, entry))
    except FileExistsError:
        pass


def response(flow):
    if "api.anthropic.com" not in flow.request.pretty_host:
        return
    if "/v1/messages" not in flow.request.path:
        return
    h = flow.response.headers

    five_h_util = h.get("anthropic-ratelimit-unified-5h-utilization")
    five_h_reset = h.get("anthropic-ratelimit-unified-5h-reset")
    if five_h_util is not None and five_h_reset is not None:
        rl_sample(os.path.join(CC_PAGE, "limit-5h.d"), "5h",
                  float(five_h_util) * 100, float(five_h_reset))

    seven_d_util = h.get("anthropic-ratelimit-unified-7d-utilization")
    seven_d_reset = h.get("anthropic-ratelimit-unified-7d-reset")
    if seven_d_util is not None and seven_d_reset is not None:
        rl_sample(os.path.join(CC_PAGE, "limit-7d.d"), "7d",
                  float(seven_d_util) * 100, float(seven_d_reset))
