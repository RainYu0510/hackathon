# 繳交對接文件

**NoxCat: Riftbound Co-op** · 隊伍 水返腳(2).png（T045）· 賽道 AI × Creativity

這份文件是繳交前的對接清單。A、B 兩區塊是可直接複製使用的文案，C 需要你確認，D 是只有你能填的欄位。

---

## A. 問題與解法摘要（給主辦方）

> 以下 192 字，可直接複製。

```
多數雙人合作遊戲讓兩人能力相同，合作因此退化成兩人走同一條路。

我們把能力拆開。遊戲中有兩個重疊的空間，同一座標在兩者有不同的平台，非作用中的空間既看不見也站不上去；而只有戴護目鏡的黑貓能切換。於是看得見平台的人與踩得到的人永遠不同：貓要說出地形，狗要在看不見時相信隊友。關卡落差刻意大於一次跳躍，讓切換空間成為唯一解。

成果是三個可玩關卡，出口需兩人同時抵達，並提供瀏覽器即玩與下載版。
```

字數統計：**192 字**（不含空白與換行），符合 100–200 字。若表單上限更嚴，刪掉最後一段可縮到 159 字。

---

## B. itch.io 頁面文案

頁面：<https://kila606.itch.io/2026fht04501>

**itch.io 遊戲頁的 Description 是所見即所得編輯器，不吃 Markdown。** 貼進去的
`##`、`**`、表格的 `|` 會原樣顯示成文字，所以下面給的是**純文字版**：整段貼上就
排版正確，標題與粗體要不要加，用編輯器上方工具列自己套。

### 短介紹（Short description or tagline 欄，一行）

```
雙人同機協力解謎平台遊戲：兩個重疊的空間，只有一個人看得見。
```

### 頁面描述（Description 欄，純文字，直接整段貼）

```text
兩個空間，一副護目鏡

同一個座標，在常態空間與異空間有不同的平台。沒作用的那個空間，你既看不見它、也站不上去。

而只有黑貓 NoxCat 能切換空間 —— 賽博狗 CyberDog 完全沒有這個能力，只能等貓幫牠開路。

所以看得見平台的人要說出來，踩得到平台的人要相信。這是一款必須說話的合作遊戲。


操作方式

兩名玩家共用一台鍵盤，本作沒有單人模式 —— 出口需要兩個人同時站進門框才會打開。

玩家 1 · NoxCat 黑貓：移動 A / D，跳躍 W，攻擊 F，互動或切換空間 G

玩家 2 · CyberDog 賽博狗：移動 ← / →，跳躍 ↑，攻擊 K，互動或切換空間 L

遊戲中 Esc 暫停、R 重新開始本關、F1 顯示除錯資訊。

請先點一下遊戲畫面，鍵盤才會有反應。


三個關卡

1. 鑰匙折返 —— 拿到護目鏡，交替切換空間爬過階梯，在最右端取得鑰匙後帶回起點的門。

2. 雙空間垂直塔 —— 左側階梯只存在於常態空間，右側只存在於異空間。邊爬邊換。

3. 誘敵破牆 —— 凹槽裡的史萊姆在巡邏。切到異空間會激怒牠，把牠引向裂開的牆讓牠自己撞開通道。牠只發現跟牠同一層的玩家，所以高台上的貓是安全的。撞歪了牠會暈一下回去巡邏，可以再誘一次。

注意：被衝刺中的史萊姆撞到是一擊死亡，整關會重新開始。


已知限制

‧ 音效只覆蓋玩家動作，沒有背景音樂
‧ 目前三關，第三關為最後一關
‧ 攻擊鍵在這三關沒有可攻擊的目標
‧ 沒有存檔


影片介紹

https://www.youtube.com/watch?v=-BpBtdmxIQQ


關於

黑客松作品，隊伍 水返腳(2).png（T045）。以 Godot 4.7.2 製作，版本 v1.0.0。

玩家一操作的黑貓 NoxCat 是 NOXCAT 官方 IP 的衍生形象，依 NOXCAT IP Usage Guidelines 以官方素材包為參考圖重新生成，權利由 NOXCAT 保留。本作為獨立參賽作品，與 NOXCAT 無合作或背書關係。

程式碼採 MIT 授權。原始碼、開發日誌與完整的第三方素材授權揭露都在 GitHub：
https://github.com/RainYu0510/hackathon

角色與場景美術以 OpenAI ChatGPT Images 2.0 生成後由團隊切幀處理，音效由團隊撰寫的合成腳本程式化產生，中文字型為 Noto Sans TC 子集（SIL OFL 1.1）。
```

> 貼上後值得用工具列補的三處：三個小標（「操作方式」「三個關卡」「關於」）套 Heading，
> 「已知限制」那四行套項目符號清單，以及「注意：被衝刺中的史萊姆…」那句套粗體。
> 不做也不影響閱讀，只是純文字段落。

### 建議的 tags

```
co-op, local-multiplayer, couch-co-op, puzzle-platformer, 2-player, asymmetric, dimensions, godot
```

### Embed 設定提醒

Viewport `1280×720`、勾 Fullscreen button、**不要勾 SharedArrayBuffer support**（本作 Web 匯出是單執行緒，勾了反而只有 Chrome 能跑）。詳見 [release-guide.md](release-guide.md)。

---
## C. 第三方揭露清單 — 請你確認

主辦方的檢核項要求揭露第三方套件、模型、資料與素材的來源及授權。你說「有用的才要」，所以下面是**實際進入成品或實際參與製作**的精簡版。

### 建議保留（八項）

| # | 項目 | 來源 | 授權 | 為什麼要列 |
|---|---|---|---|---|
| 1 | Godot Engine 4.7.2 stable | <https://godotengine.org> | MIT License | 遊戲引擎，且 Web 版直接包含引擎產生的 JS/WASM 執行期程式碼 |
| 2 | **NOXCAT 官方 IP 素材（`NOXCAT IP_01`～`_04`）** | 賽道提供的 NOXCAT 官方素材包 | **NOXCAT 保留權利**（IP Usage Guidelines 第七條） | **玩家一的黑貓角色 NoxCat 是它的衍生形象**，以參考圖方式重新生成。這是進入成品的第三方 IP，一定要列。活動後續發布須另取得書面同意 |
| 3 | Noto Sans TC（子集） | [Google Fonts](https://github.com/google/fonts/tree/main/ofl/notosanstc) | **SIL OFL 1.1** | 另一項內嵌進成品的第三方素材。OFL 明文要求散布時附上授權條文，這一項不能省 |
| 4 | OpenAI ChatGPT Images 2.0（`gpt-image-2`） | OpenAI | 依 OpenAI 使用條款，產出歸使用者 | 全部美術素材由它生成（含 NOXCAT 角色的重新生成），屬於檢核項明確點名的「模型」 |
| 5 | OpenAI ChatGPT | OpenAI | — | 開發期的設計討論與流程諮詢。主辦方的 Pro／API 額度未開通，使用團隊自有帳號 |
| 6 | OpenAI Codex | OpenAI | — | 撰寫 `tools/generate_dog_sfx.js` 音效合成腳本 —— 遊戲裡聽到的每一個音效都源自它產出的程式碼 |
| 7 | Anthropic Claude Code | Anthropic | — | 參與程式碼與文件撰寫，相關 commit 有 `Co-Authored-By` 標記，主動揭露比被發現好 |
| 8 | 團隊自製：程式碼、關卡、CyberDog 與其餘美術、`data/level_02.json`、8 個程式化合成音效（腳本由 Codex 協助撰寫，音檔為腳本輸出，非取樣素材） | 團隊 | MIT | 說明「哪些是我們自己做的」，這是清單的對照基準 |

### 建議不列進精簡清單（三項，理由如下）

| 項目 | 為什麼建議不列 |
|---|---|
| 3 個 Pixabay mp3（`jump.mp3`、`slime dead.mp3`、`slime walk.mp3`） | 來源已確認為 [Pixabay](https://pixabay.com/)（Pixabay Content License，免費商用、無需署名）。程式碼從未引用，`exclude_filter` 也讓它們從未進入任何發布版本，**且已於繳交前自儲存庫刪除**。既然成品沒有用到、也不再散布，就不列進給主辦方的精簡清單。**`CREDITS.md` 第 4.2 節保留完整紀錄** —— git 歷史裡還看得到，寫清楚比刪乾淨更重要 |
| 根目錄 5 個素材原始 zip | 那是我們自己 AI 生成流程的原始交付包，內容已解壓到 `assets/`，不是第三方取得的素材。歸在第 3 項底下就夠了 |
| 29 張未被引用的 PNG、Godot 內建預設字型 | 前者是我們自己生成的閒置素材、後者未實際使用（已被內嵌字型取代），都不構成第三方授權事項 |

### 已定案（2026-09-05）

- [x] 七項保留清單照這樣交
- [x] AI 協作全部列出：ChatGPT Images 2.0、ChatGPT、Codex、Claude Code 四項都在清單內
- [x] 三個 mp3 的來源確認為 Pixabay；精簡清單不列、`CREDITS.md` 保留紀錄，並將檔案自儲存庫移除

完整詳細版一律以 [CREDITS.md](../CREDITS.md) 為準，這份只是給主辦方表單用的濃縮版。

---

## D. 需要你自己填的欄位

| # | 欄位 | 要填進哪裡 | 現在的狀態 |
|---|---|---|---|
| 1 | 主辦方繳交表單的其他欄位 | 表單 | A 區塊的摘要、C 區塊的清單可直接用 |

itch.io 網址已於 2026-09-05 填入四處（兩份 README 的方式一／Option 1 與作品展示／Showcase 節、`docs/release-guide.md` 的 Release 說明草稿）：<https://kila606.itch.io/2026fht04501>

---

## 目前的繳交狀態

| 檢核項 | 狀態 |
|---|---|
| 無痕視窗可直接開啟 | ✅ repo 為 public |
| 包含可辨識的實作內容 | ✅ `main` 有完整專案 |
| README 六要素完整 | ✅ 中英雙語，照官方範本十節 |
| 明確的 LICENSE | ✅ MIT，版權人為隊名 |
| 第三方來源與授權已揭露 | ✅ `CREDITS.md` + 本文件 C 區塊 |
| 無 API Key／Token／密碼／個人資料 | ✅ 全樹掃描無命中 |
| 可下載即玩的版本 | ⏳ 打包檔已產出，待你建立 GitHub Release |
| 線上即玩 | ✅ <https://kila606.itch.io/2026fht04501> |
| 評選影片 | ✅ <https://www.youtube.com/watch?v=-BpBtdmxIQQ> |
