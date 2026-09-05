#!/usr/bin/env bash
# 冪等地安裝 Godot 匯出範本到 Flatpak 版 Godot 的 userdata 目錄。
#
# 為什麼要手動裝:編輯器的「管理匯出範本」對話框需要互動操作,而這台機器
# 上的自動化流程沒辦法驅動編輯器 GUI。tpz 就是個 zip,自己解開放對位置
# 即可,行為與編輯器安裝的結果相同。
#
# 用法:
#   tools/install_export_templates.sh [tpz 檔路徑]
# 不給路徑時,會下載到 /tmp 再安裝。

set -euo pipefail

VERSION="4.7.2.stable"
URL="https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
DEST="${HOME}/.var/app/org.godotengine.Godot/data/godot/export_templates/${VERSION}"
TPZ="${1:-/tmp/Godot_v4.7.2-stable_export_templates.tpz}"

# 已安裝就直接結束(冪等)
if [[ -f "${DEST}/version.txt" ]] && [[ "$(cat "${DEST}/version.txt")" == "${VERSION}" ]]; then
    echo "[install] ${VERSION} 已安裝於 ${DEST},跳過"
    exit 0
fi

if [[ ! -f "${TPZ}" ]]; then
    echo "[install] 下載範本(約 1.2 GB)…"
    curl -fL --retry 3 -o "${TPZ}" "${URL}"
fi

# 先確認壓縮檔裡的版本與成員名符合預期,再動手解 ——
# 4.3+ 起 no-threads 是獨立的範本檔(web_nothreads_*.zip),
# 名字對不上就代表版本假設錯了,寧可停下來也不要裝出一個壞掉的組合。
ZIP_VERSION="$(unzip -p "${TPZ}" templates/version.txt)"
if [[ "${ZIP_VERSION}" != "${VERSION}" ]]; then
    echo "[install] 版本不符:壓縮檔是 ${ZIP_VERSION},預期 ${VERSION}" >&2
    exit 1
fi
for member in web_nothreads_release.zip web_nothreads_debug.zip; do
    if ! unzip -l "${TPZ}" "templates/${member}" >/dev/null 2>&1; then
        echo "[install] 壓縮檔缺少 templates/${member}" >&2
        exit 1
    fi
done

echo "[install] 解壓到 ${DEST}"
mkdir -p "${DEST}"
# tpz 內容都在 templates/ 底下,但安裝位置不要那一層,所以用 -j 攤平。
unzip -o -q -j "${TPZ}" 'templates/*' -d "${DEST}"

echo "[install] 完成,$(ls -1 "${DEST}" | wc -l) 個檔案"
