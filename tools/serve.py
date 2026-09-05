#!/usr/bin/env python3
"""給瀏覽器檢視 Web 匯出用的本機靜態伺服器。

這不是測試工具,只是把 build/web/ 端出來讓 Chrome 打得開。存在的主要理由是
`Cache-Control: no-store`:重新匯出之後 Chrome 若拿到快取的舊 wasm,看起來
會像「改動沒生效」,那是個很花時間的誤判。

不送 COOP/COEP —— 匯出走 no-threads 不需要跨源隔離。真的切到 threads 模式
再加,不要為了「以防萬一」先送,那會讓失敗模式變得更難分辨。

用法(Windows 上 `python` 可能是 Microsoft Store 的 stub,用 `py`):

    py tools/serve.py
"""

import functools
import http.server
import sys
from pathlib import Path

PORT = 8099
ROOT = Path(__file__).resolve().parent.parent / "build" / "web"


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".js": "text/javascript",
        ".json": "application/json",
    }

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store, max-age=0")
        super().end_headers()


def main() -> int:
    if not (ROOT / "index.html").is_file():
        print(f"找不到 {ROOT / 'index.html'}", file=sys.stderr)
        print("先匯出:godot --headless --path . --export-release Web build/web/index.html",
              file=sys.stderr)
        return 1

    handler = functools.partial(Handler, directory=str(ROOT))
    with http.server.ThreadingHTTPServer(("127.0.0.1", PORT), handler) as httpd:
        print(f"serving {ROOT}")
        print(f"http://localhost:{PORT}/   (Ctrl+C 停止)")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nstopped")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
