# 第三方服務、資料與素材揭露

本文件逐項列出 **NoxCat: Riftbound Co-op** 使用到的所有外部資源、其來源與授權狀態。

隊伍：水返腳(2).png（T054）
最後更新：2026-09-05（對應 commit `1298e0c`）

開發過程的逐次決策紀錄見 [`development-log/`](development-log/)（共 5 篇），其中素材製作流程見 [sprite pipeline 那篇](development-log/2026-09-04-sprite-pipeline-and-player-art.md)，最新的選單與敵人重做見 [這篇](development-log/2026-09-05-menu-exit-unify-slime-rework.md)。

> **本儲存庫不包含任何 API 金鑰、Token、密碼、憑證或個人資料檔案。**
> 全樹掃描結果：無 `.env`、無 keystore／簽章憑證、無 CI secret、無私鑰、檔案內容中無電子郵件位址。

---

## 1. 引擎與執行期

| 項目 | 來源 | 授權 | 備註 |
|---|---|---|---|
| Godot Engine 4.7.2 stable | <https://godotengine.org> · <https://github.com/godotengine/godot> | MIT License | 遊戲引擎。專案未使用 .NET／C# 版本 |
| Godot Web 執行期（`index.js`、`index.wasm`、audio worklets） | 由 Godot 匯出流程自動產生 | MIT License（Godot Engine contributors；Juan Linietsky, Ariel Manzur） | 僅存在於 Web 匯出產物中，不在原始碼樹內 |

**無任何第三方外掛（addon／plugin）。** 專案沒有 `addons/` 目錄，`project.godot` 中也沒有 `[editor_plugins]` 區段。

## 2. 程式碼

| 項目 | 來源 | 授權 |
|---|---|---|
| 全部 GDScript 原始碼（`actors/`、`autoload/`、`components/`、`interactables/`、`levels/`、`systems/`） | 團隊自行撰寫 | MIT（見 [LICENSE](LICENSE)） |
| `tools/generate_dog_sfx.js` | 團隊自行撰寫（Node.js） | MIT |
| `tools/serve.py` | 團隊自行撰寫（Python 3 標準函式庫） | MIT |
| `tools/install_export_templates.sh` | 團隊自行撰寫 | MIT |

遊戲的基礎實作來自隊員 tony（GitHub `0812tony96`）交付的 `NoxCat_Riftbound_Godot4_FIXED_v4.zip`。**這是團隊成員自行開發的內容，不是外部取得的模板或範例專案**，因此同樣涵蓋於本專案的 MIT 授權之下。

## 3. 美術素材

| 項目 | 數量 | 來源 | 授權 |
|---|---|---|---|
| 角色動畫（NoxCat、CyberDog） | — | AI 影像生成 + 團隊自寫切幀流程 | 見下方說明 |
| 敵人動畫（史萊姆，衝刺怪借用並上色） | — | 同上 | 同上 |
| 空間背景、平台、傳送門 | — | 同上 | 同上 |
| 互動物件圖示（護目鏡、鑰匙、門、牆面） | — | 同上 | 同上 |
| **合計** | **152 張 PNG** | | |

**生成方式與工具**

素材以 **OpenAI ChatGPT 的影像生成功能**產出接觸表（contact sheet），再由團隊自寫的切幀流程處理成單幀 PNG。

- 使用模型：**ChatGPT Images 2.0**（API 名稱 `gpt-image-2`）。此模型於 2026-04-21 上線，取代先前的 GPT-4o 影像管線、DALL·E 3 與 GPT Image 1.5
- 使用方式：透過 ChatGPT 介面，使用團隊成員自有帳號
- 生成期間：2026-09-04 至 2026-09-05
- 後製：接觸表以團隊自行撰寫的切幀流程分割、去背、對齊腳底基線後輸出。流程與遭遇的問題記錄於 [`development-log/2026-09-04-sprite-pipeline-and-player-art.md`](development-log/2026-09-04-sprite-pipeline-and-player-art.md)

**授權狀態**

依 OpenAI 使用條款，使用者對其輸入與模型產出的內容擁有權利。本專案的美術素材依此隨專案的 MIT 授權散布。

> 中性說明：AI 生成內容在部分司法管轄區的著作權保護範圍仍有討論空間。此處揭露的是生成方式與時間的事實，不構成法律意見。

**素材原始交付檔**

儲存庫根目錄的五個 `.zip` 是上述流程的原始交付包，內容已全部解壓至 `assets/` 之下，保留供追溯：

`CYBER_DOG_character_Godot.zip`、`NOXCAT_sprites_Godot.zip`、`NOXCAT_white_background_Godot.zip`、`NOXCAT_dimension_pack.zip`、`NOXCAT_contrast_dimension.zip`

## 4. 音訊素材

### 4.1 程式化合成的音效（8 個 WAV）—— 原創

| 檔案 | 來源 | 授權 |
|---|---|---|
| `assets/audio/dog_attack.wav` | | |
| `assets/audio/dog_death.wav` | | |
| `assets/audio/dog_device.wav` | | |
| `assets/audio/dog_hit.wav` | [`tools/generate_dog_sfx.js`](tools/generate_dog_sfx.js) | MIT（隨本專案） |
| `assets/audio/dog_idle.wav` | 程式化合成 | |
| `assets/audio/dog_jump.wav` | | |
| `assets/audio/dog_run.wav` | | |
| `assets/audio/dog_sfx_preview.wav` | | |

這些檔案由一支 Node.js 腳本逐位元組寫出：手寫 RIFF/WAVE 標頭、以線性同餘產生器製造雜訊、搭配正弦包絡塑形，輸出 16-bit 單聲道 44.1 kHz PCM。**完全原創，未使用任何取樣素材或音效庫。** 執行 `node tools/generate_dog_sfx.js` 即可重新產生。

### 4.2 來源待確認的音效（3 個 MP3）

| 檔案 | 來源 | 授權 | 處置 |
|---|---|---|---|
| `assets/audio/jump.mp3` | **未確認** | **未確認** | 已排除於所有發布版本 |
| `assets/audio/slime dead.mp3` | **未確認** | **未確認** | 同上 |
| `assets/audio/slime walk.mp3` | **未確認** | **未確認** | 同上 |

這三個檔案由隊員（GitHub `DecorousGoat914`）經 GitHub 網頁介面上傳，檔案本身無內嵌 metadata，上傳時亦未附帶來源或授權說明。團隊目前無法確認其出處。

採取的處置：

1. **不隱瞞** —— 在此誠實揭露其狀態為未確認
2. **不使用** —— 專案程式碼中沒有任何一處引用這三個檔案（遊戲目前不播放任何音效）
3. **不散布** —— `export_presets.cfg` 的 `exclude_filter` 設為 `*.mp3`，因此它們**不會被打包進任何匯出的執行檔或 Web 版本**

來源與授權確認之前，這三個檔案僅存在於原始碼樹中，不進入任何發布產物。

## 5. 字型與 UI 主題

專案**未包含任何字型檔**（無 `.ttf`／`.otf`／`.woff`）。所有畫面文字使用 Godot 引擎內建的預設字型。

| 項目 | 來源 | 授權 | 備註 |
|---|---|---|---|
| `ui/menu_theme.tres` | 團隊自行製作 | MIT（隨本專案） | 主選單與暫停選單共用的 Godot `Theme` 資源。純設定資料（顏色、字級、邊框），不含任何外部素材或字型檔 |

這是專案中唯一的 `.tres` 資源檔。

## 6. 資料

| 項目 | 來源 | 授權 |
|---|---|---|
| `data/level_02.json` | 團隊自製的第二關關卡幾何資料 | MIT（隨本專案） |

**未使用任何外部資料集。** 遊戲執行時不讀取本機檔案以外的任何資料，也不發出網路請求。

## 7. 發布平台

| 平台 | 用途 |
|---|---|
| [itch.io](https://itch.io) | HTML5 版本託管，提供瀏覽器直接遊玩 |
| GitHub Releases | Windows 桌面版下載 |

兩者皆為發布通道，不涉及程式碼相依或執行期整合。

## 8. 開發過程中使用的 AI 工具

為求揭露完整，一併列出參與開發流程的 AI 工具：

| 工具 | 用途 |
|---|---|
| OpenAI ChatGPT（ChatGPT Images 2.0 / `gpt-image-2`） | 美術素材生成（見第 3 節） |
| Anthropic Claude Code | 部分程式碼撰寫、專案文件與匯出流程協助。相關 commit 於訊息中標註 `Co-Authored-By` |

主辦方原訂提供的 OpenAI Pro 方案與 API 額度至繳交前尚未開通，因此上述素材生成使用團隊成員的自有帳號完成，未動用贊助額度，遊戲執行時亦未呼叫任何 OpenAI API。

---

## 授權總結

- **程式碼、關卡資料、程式化合成音效**：MIT License，Copyright (c) 2026 水返腳(2).png (Team T054)，見 [LICENSE](LICENSE)
- **美術素材**：AI 生成後由團隊後製，依 OpenAI 使用條款隨本專案 MIT 散布
- **三個 MP3**：來源未確認，未使用、未散布
- **Godot Engine**：MIT License，版權歸 Godot Engine contributors
