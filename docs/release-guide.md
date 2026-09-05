# 發布指南：GitHub Release 與 itch.io

這份文件給團隊成員操作用。分兩部分：**A. GitHub Release**（提供 Windows 下載版）、**B. itch.io**（提供瀏覽器即玩版）。

打包好的檔案在 `build/` 目錄下：

| 檔案 | 大小 | 上傳到哪裡 |
|---|---|---|
| `build/NoxCat-Riftbound-Coop-v1.0.0-windows.zip` | 約 55 MB | **GitHub Release** —— 下載即玩的桌面版，Release 的主角 |
| `build/NoxCat-Riftbound-Coop-v1.0.0-web.zip` | 約 29 MB | **itch.io**（線上即玩）**與 GitHub Release 兩邊都放** —— 同一個檔案。附在 Release 裡是讓這個版本的 HTML5 建置有固定存檔，itch.io 頁面若出問題評審還有東西可拿 |

所以 Release 的 Assets 會有**兩個** zip，itch.io 只需要 web 那一個。

> `build/` 已列入 `.gitignore`，這兩個 zip 不會進版控 —— 它們是要「上傳」的產物，不是要「提交」的原始碼。

---

# A. GitHub Release

## A-1. Release 是什麼？為什麼需要它？

你的 repo 裡放的是**原始碼**。別人要玩，得先安裝 Godot、把專案打開、按 F5 —— 這對評審是額外門檻，而且有人會卡在版本不對。

**Release 解決的就是這件事**：它是掛在 repo 上的一個獨立發布頁，你可以在上面附加「已經打包好的執行檔」。評審點進去、下載 zip、解壓、雙擊，就開始玩，完全不需要碰 Godot。

三個名詞：

| 名詞 | 意思 |
|---|---|
| **tag（標籤）** | 給某一個 commit 貼上一個版本名字，例如 `v1.0.0`。它是一個**固定的時間點快照** —— 之後你再改程式碼，這個 tag 指向的永遠還是當初那一份 |
| **Release** | 掛在某個 tag 上的發布頁，有標題、說明文字，以及你上傳的檔案 |
| **Assets（附加檔案）** | 你上傳的那些 zip。GitHub 會自動附上原始碼的壓縮檔，但那只是原始碼 —— **你自己上傳的執行檔才是能直接玩的那一份**，這是 Release 真正的重點 |

順序永遠是：**先有 tag → 建 Release → 上傳檔案 → Publish**。

## A-2. 先建 tag 並推上去

在專案目錄執行：

```bash
# 確認在 main 分支、而且該提交的都提交了
git status

# 建立 tag（-a 是帶說明的標註型 tag，-m 是說明文字）
git tag -a v1.0.0 -m "黑客松繳交版"

# 把 tag 推到 GitHub（注意：一般的 git push 不會帶 tag，要單獨推）
git push origin v1.0.0
```

> **常見錯誤**：只跑 `git push` 沒跑 `git push origin v1.0.0`，結果 GitHub 上看不到 tag。tag 必須單獨推。

如果 tag 打錯要重來：

```bash
git tag -d v1.0.0                  # 刪本機的
git push origin --delete v1.0.0    # 刪遠端的
```

## A-3. 在 GitHub 網頁建立 Release

1. 打開 <https://github.com/RainYu0510/hackathon>
2. 右側欄找到 **Releases**，點進去（或直接開 <https://github.com/RainYu0510/hackathon/releases>）
3. 點 **Draft a new release**
4. **Choose a tag** 下拉選單 → 選剛才推上去的 `v1.0.0`
   （如果沒推 tag，也可以在這裡直接輸入 `v1.0.0` 讓 GitHub 幫你建，它會建在目前的 `main` 上）
5. **Release title** 填：
   ```
   NoxCat: Riftbound Co-op v1.0.0 — 黑客松繳交版
   ```
6. **Describe this release** 貼上 A-4 的說明草稿
7. 把**兩個 zip**（windows 與 web）**拖曳**到「Attach binaries by dropping them here or selecting them」那一塊，等它上傳完（Windows 版 55 MB，會跑一下）
8. **Set as the latest release** 保持勾選
9. 點 **Publish release**

發布後檢查：**開一個無痕視窗**打開 Releases 頁面，確認不登入也看得到、而且兩個 zip 都能下載。這一步很重要 —— 評審就是用無痕視窗看的。

## A-4. Release 說明文字（可直接複製貼上）

```markdown
雙人同機協力解謎平台遊戲。隊伍：水返腳(2).png（T045）· 賽道 AI × Creativity

玩家一的黑貓 NoxCat 是 NOXCAT 官方 IP 的衍生形象（依 NOXCAT IP Usage Guidelines 以官方素材包為參考圖重新生成，權利由 NOXCAT 保留）。本作為獨立參賽作品，與 NOXCAT 無合作或背書關係。

## 下載與執行

**Windows**：下載 `NoxCat-Riftbound-Coop-v1.0.0-windows.zip` → 解壓縮 → 雙擊 `NoxCat-Riftbound-Coop.exe`
所有資源已內嵌在執行檔中，不需要安裝 Godot。

**瀏覽器**：不想下載可以直接線上玩 —— <https://kila606.itch.io/2026fht04501>（同一份建置，也就是本頁附的 `NoxCat-Riftbound-Coop-v1.0.0-web.zip`）。

## 影片介紹

https://www.youtube.com/watch?v=-BpBtdmxIQQ

## 操作方式

兩名玩家共用一台鍵盤。

| | 玩家 1（NoxCat 黑貓） | 玩家 2（CyberDog 賽博狗） |
|---|---|---|
| 移動 | A / D | ← / → |
| 跳躍 | W | ↑ |
| 攻擊 | F | K |
| 互動／切換空間 | G | L |

遊戲中按 `Esc` 暫停，`R` 重新開始本關，`F1` 顯示除錯資訊。

## 這個版本包含

- 三個可玩關卡：鑰匙折返、資料驅動的垂直塔、誘導敵人破牆
- 雙空間疊合機制：非作用中的空間同時看不見也站不上去
- 不對稱能力：只有黑貓能切換空間
- 主選單與選關、Esc 暫停
- 出口需要兩名玩家同時抵達

## 已知限制

音效只覆蓋玩家動作（跑、跳、攻擊、受擊、死亡、裝置），沒有背景音樂。完整的限制清單見 [README](https://github.com/RainYu0510/hackathon#限制與未來工作)。

## 授權

MIT License。第三方素材與 AI 生成內容的來源揭露見 [CREDITS.md](https://github.com/RainYu0510/hackathon/blob/main/CREDITS.md)。
```

## A-5. 發布後如果要修

- **只改說明文字**：Release 頁面右上角 **Edit release** → 改 → **Update release**
- **要換掉附加檔案**：Edit release → 舊檔案旁邊的垃圾桶圖示刪掉 → 重新拖新檔案上傳
- **程式碼有更新**：不要覆蓋 `v1.0.0`。建新 tag（例如 `v1.0.1`）再建一個新的 Release，讓每個版本對應一份固定的檔案

---

# B. itch.io

## B-1. 建立專案

1. 到 <https://itch.io> 註冊或登入
2. 右上角頭像 → **Upload new project**（或開 <https://itch.io/game/new>）
3. **Title** 填 `NoxCat: Riftbound Co-op`
4. **Classification** 保持 `Games`
5. **Kind of project** 選 **HTML** ← **這一項最關鍵**，選錯就變成純下載頁而不是可線上玩

## B-2. 上傳 Web 版

1. 在 **Uploads** 區塊點 **Upload files**，選 `build/NoxCat-Riftbound-Coop-v1.0.0-web.zip`
2. 上傳完成後，**勾選該檔案下方的 `This file will be played in the browser`**
   （沒勾這個，itch.io 只會把它當成一個下載用的 zip，不會執行）

## B-3. Embed options（嵌入設定）

| 設定 | 值 | 原因 |
|---|---|---|
| Viewport dimensions | **1280 × 720** | 與 `project.godot` 的視窗尺寸一致，避免畫面被裁切 |
| **Fullscreen button** | 勾選 | 讓玩家可以全螢幕 |
| Mobile friendly | 不勾 | 本作需要鍵盤，且是雙人同機 |
| **Enable scrollbars** | 不勾 | |
| **SharedArrayBuffer support** | **不要勾** | 見下方說明 |

> **為什麼不能勾 SharedArrayBuffer support？**
> 本專案的 Web 匯出是**單執行緒**（`export_presets.cfg` 裡 `variant/thread_support=false`）。單執行緒版本不需要 SharedArrayBuffer，而且相容性最好 —— Chrome、Firefox、Edge 都能跑。
> 如果勾了那個選項，itch.io 會加上跨來源隔離標頭，實務上會讓部分瀏覽器（尤其 Firefox）反而載入失敗。**不勾才是相容性最高的選擇。**

## B-4. 發布與驗證

1. 頁面底部 **Visibility & access** 選 **Public**
2. 點 **Save & view page**
3. **開一個無痕視窗**貼上頁面網址，確認：
   - 不登入也能看到頁面
   - 點 Run game 後遊戲能載入（第一次載入要下載約 60 MB，會等一段時間）
   - **看得到主選單**（如果直接跳進第一關，表示上傳的是舊版打包檔）
   - 鍵盤能操作 —— 點一下遊戲畫面把焦點給它，再按鍵

## B-5. 拿到網址後要回填

**本專案的頁面：<https://kila606.itch.io/2026fht04501>** —— 已經填進下列位置，不需要再動：

1. `README.md`「安裝與執行 → 方式一：瀏覽器直接玩」與「作品展示」節
2. `README.en.md` 的 Option 1 與 Showcase 節
3. 本文件 A-4 的 Release 說明草稿

之後若換網址，以上四處要一起改，漏掉任何一處都會留下死連結。

---

# C. 打包檔怎麼重新產生

如果程式碼有更新，要重新產生打包檔：

```bash
# 1. 清掉舊產物（很重要 —— 混到舊檔會發布出錯誤的版本）
rm -rf build/web build/windows
mkdir -p build/web build/windows

# 2. 重新匯出
godot --headless --import
godot --headless --export-release "Windows Desktop" build/windows/NoxCat-Riftbound-Coop.exe
godot --headless --export-release "Web" build/web/index.html
```

```powershell
# 3. 打包（PowerShell）
Compress-Archive -Path 'build\web\*'     -DestinationPath 'build\NoxCat-Riftbound-Coop-v1.0.0-web.zip'     -Force
Compress-Archive -Path 'build\windows\*' -DestinationPath 'build\NoxCat-Riftbound-Coop-v1.0.0-windows.zip' -Force
```

> **`build\web\*` 的星號是關鍵。** 有星號 → `index.html` 在 zip 的最上層，itch.io 找得到入口。沒星號 → zip 裡是一個 `web` 資料夾，itch.io 會顯示空白畫面。

```bash
# 4. 本機驗證 Web 版（開 http://127.0.0.1:8099）
python tools/serve.py
```

`tools/serve.py` 送 `Cache-Control: no-store`，避免瀏覽器拿到快取的舊 wasm —— 那會讓你以為「改動沒生效」，很浪費時間。

## 每次發布前的檢查清單

- [ ] 匯出產物的時間戳比最新 commit 新（確認不是舊版）
- [ ] Web zip 裡 `index.html` 在最上層
- [ ] Web zip 裡沒有任何 `.mp3`（`exclude_filter` 的保險仍在；那三個 Pixabay 音檔已於 2026-09-05 自儲存庫移除）
- [ ] Windows zip 裡有 `NoxCat-Riftbound-Coop.exe` 與 `操作說明.txt`
- [ ] 本機跑起來看得到**主選單**
- [ ] 無痕視窗能開 Release 頁面並下載
- [ ] 無痕視窗能開 itch.io 頁面並遊玩
