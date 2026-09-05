# 第三方服務、資料與素材揭露

本文件逐項列出 **NoxCat: Riftbound Co-op** 使用到的所有外部資源、其來源與授權狀態。

隊伍：水返腳(2).png（T045）
最後更新：2026-09-05（對應 commit `b487b1e`）

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
| 角色動畫 **NoxCat（黑貓）** | — | **以 NOXCAT 官方 IP 素材包為參考圖，AI 影像生成 + 團隊自寫切幀流程** | **NOXCAT 保留權利，見 3.1** |
| 角色動畫 CyberDog（賽博狗） | — | AI 影像生成 + 團隊自寫切幀流程（原創角色） | 見下方說明 |
| 敵人動畫（史萊姆，衝刺怪借用並上色） | — | 同上 | 同上 |
| 空間背景、平台、傳送門 | — | 同上 | 同上 |
| 互動物件圖示（護目鏡、鑰匙、門、完整牆面與裂開牆面） | — | 同上 | 同上 |
| **合計** | **153 張 PNG** | | |

**生成方式與工具**

素材以 **OpenAI ChatGPT 的影像生成功能**產出接觸表（contact sheet），再由團隊自寫的切幀流程處理成單幀 PNG。

- 使用模型：**ChatGPT Images 2.0**（API 名稱 `gpt-image-2`）。此模型於 2026-04-21 上線，取代先前的 GPT-4o 影像管線、DALL·E 3 與 GPT Image 1.5
- 使用方式：透過 ChatGPT 介面，使用團隊成員自有帳號
- 生成期間：2026-09-04 至 2026-09-05
- 後製：接觸表以團隊自行撰寫的切幀流程分割、去背、對齊腳底基線後輸出。流程與遭遇的問題記錄於 [`development-log/2026-09-04-sprite-pipeline-and-player-art.md`](development-log/2026-09-04-sprite-pipeline-and-player-art.md)

**授權狀態**

依 OpenAI 使用條款，使用者對其輸入與模型產出的內容擁有權利。本專案的美術素材依此隨專案的 MIT 授權散布。

> 中性說明：AI 生成內容在部分司法管轄區的著作權保護範圍仍有討論空間。此處揭露的是生成方式與時間的事實，不構成法律意見。

### 3.1 NOXCAT 官方 IP 素材（第三方 IP）

**玩家一操作的黑貓角色 NoxCat 是 NOXCAT 官方 IP 的衍生形象，不是本團隊的原創角色。**

| 項目 | 內容 |
|---|---|
| 來源 | FUTUREMODE 2026 黑客松「AI × Creativity」賽道提供的 **NOXCAT 官方素材包** |
| 參考檔案 | `NOXCAT IP_01`（正面半身）、`IP_02`（全身正反轉身）、`IP_03`（全身動作）、`IP_04`（頭部特寫） |
| 使用方式 | 以上述四張作為**參考圖輸入**，透過 ChatGPT Images 2.0 重新生成本作所需的待機／移動／跳躍／攻擊／受擊／死亡／拾取護目鏡等動作幀，再由團隊切幀處理 |
| 規範依據 | 《NOXCAT IP Usage Guidelines》第四條明訂允許重新繪製、依遊戲需求製作姿勢、配色調整、場景整合與遊戲資產化 |
| 核心識別 | 依第三條保留：黑色貓形體、螢光綠大眼、額前綠鏡片護目鏡、螢光綠為強調色。角色名稱維持 `NoxCat`，未改名 |
| 權利歸屬 | **依第七條，NOXCAT 素材及其可辨識之衍生形象，權利由 NOXCAT 保留**，不隨本專案的 MIT 授權散布 |
| 活動後 | **活動結束後如擬繼續發布、上架或商業化，須另行取得 NOXCAT 書面同意**（第七條） |

未使用之處，一併說明：

- **未使用 LOGO 素材包**。團隊雖取得 `NOXCAT LOGO_01`～`_12`，但成品中沒有任何一張 NOXCAT 標識圖檔，主選單背景為團隊自製的異空間圖
- **未訓練任何 LoRA 或微調模型**，因此不涉及第 6.2 條的模型權重散布限制
- 賽博狗 CyberDog、史萊姆、平台、背景與互動物件皆為團隊原創，非 NOXCAT 衍生

> 本作為獨立參賽作品，與 NOXCAT **不存在**合作、投資、背書或其他關係。

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

該腳本由隊員（GitHub `DecorousGoat914`）在 **OpenAI Codex** 協助下撰寫，與這 8 個 WAV 於同一個 commit（`1279c94`）提交。

「這 8 個檔案全部出自這支腳本」是可查證的：腳本的 `makeWav()` 配置 `44 + floor(秒數 × 44100) × 2` bytes，用腳本內宣告的秒數反推理論檔案大小，與磁碟上的實際大小逐位元組相符 —— `dog_idle` 0.8 秒 / 70604 bytes、`dog_run` 與 `dog_jump` 0.42 秒 / 37088 bytes、`dog_attack` 0.36 秒 / 31796 bytes、`dog_device` 0.55 秒 / 48554 bytes、`dog_hit` 0.27 秒 / 23858 bytes、`dog_death` 0.85 秒 / 75014 bytes。八個檔案的標頭也一致為 1 聲道 / 44100 Hz / 16-bit、44 bytes 裸標頭，正是 `makeWav()` 的輸出格式。

其中 6 個（`dog_run`、`dog_jump`、`dog_attack`、`dog_hit`、`dog_death`、`dog_device`）已由 `actors/players/PlayerBase.gd` 實際播放；`dog_idle.wav` 與 `dog_sfx_preview.wav` 目前未被引用。

### 4.2 已移除的第三方音效（3 個 MP3，來自 Pixabay）

| 檔案 | 來源 | 授權 | 現況 |
|---|---|---|---|
| `assets/audio/jump.mp3` | [Pixabay](https://pixabay.com/) | Pixabay Content License | **已自儲存庫移除** |
| `assets/audio/slime dead.mp3` | [Pixabay](https://pixabay.com/) | Pixabay Content License | 同上 |
| `assets/audio/slime walk.mp3` | [Pixabay](https://pixabay.com/) | Pixabay Content License | 同上 |

這三個檔案由隊員（GitHub `DecorousGoat914`）自 Pixabay 取得後，經 GitHub 網頁介面上傳（commit `d0778de` 與 `9ea5b9d`）。檔案本身沒有內嵌 metadata，因此無法回溯到個別的素材頁面網址。

Pixabay Content License 允許免費用於商業與非商業用途、無需署名，但不得將素材本身原樣轉售或再散布。本專案的處置是：

1. **從未使用** —— 專案程式碼中沒有任何一處引用這三個檔案。遊戲實際播放的音效全部來自 4.1 節程式化合成的 `dog_*.wav`
2. **從未散布** —— `export_presets.cfg` 的 `exclude_filter` 設為 `*.mp3`，它們不曾被打包進任何匯出的執行檔或 Web 版本（打包後的 pck 內 mp3 數量為 0，已實際驗證）
3. **已移除** —— 既然沒有使用，繳交前已將這三個檔案自工作樹刪除，避免散布未使用的第三方素材

`exclude_filter="*.mp3"` 保留在 `export_presets.cfg` 中，作為日後誤加 mp3 的保險。git 歷史中仍可見這些檔案，此節即為其紀錄。

## 5. 字型與 UI 主題

| 項目 | 來源 | 授權 | 備註 |
|---|---|---|---|
| `assets/fonts/NotoSansTC-Subset.ttf` | **Noto Sans TC**（Google Fonts）<br><https://github.com/google/fonts/tree/main/ofl/notosanstc> | **SIL Open Font License 1.1**<br>條文全文見 [`assets/fonts/NotoSansTC-OFL.txt`](assets/fonts/NotoSansTC-OFL.txt) | **除了第 3.1 節的 NOXCAT 衍生角色美術之外，這是本專案唯一的第三方素材。** 原字型 11.9 MB，經 [`tools/make_font_subset.py`](tools/make_font_subset.py) 切成子集後為 1.9 MB（保留 5748 個字形：Big5 常用字、ASCII、Latin-1 與常用標點），並將可變字重固定為 Regular。詳見下方說明 |
| `ui/menu_theme.tres` | 團隊自行製作 | MIT（隨本專案） | 主選單與暫停選單共用的 Godot `Theme` 資源。純設定資料（顏色、字級、邊框） |

### 為什麼需要內嵌字型

Godot 內建的預設字型不含中日韓字符。桌面版看起來正常，是因為 Godot 會向作業系統的字型求援；但 **Web 匯出沒有系統字型可用**，所有中文都會顯示成豆腐方塊。因此必須把中文字型內嵌進專案，設定於 `project.godot` 的 `gui/theme/custom_font`。

### SIL OFL 1.1 的遵循方式

OFL 允許修改與再散布（切子集屬於修改），但要求：

1. **散布時必須附上授權條文** —— `assets/fonts/NotoSansTC-OFL.txt` 保留在儲存庫中，並隨兩個發布用的 zip 一併散布
2. **保留 Reserved Font Name** —— 子集化過程以 `name_IDs = ["*"]` 保留原字型的名稱與授權欄位，未改動字型名稱
3. **子集字型本身仍受 OFL 1.1 約束**，不隨本專案的 MIT 授權

注意：Noto Sans TC 衍生自 Adobe 的 Source Han Sans，其 OFL 條文中的版權聲明為 `Copyright 2014-2021 Adobe`，保留字型名稱為 `Source`。

**未使用任何專有字型。** 特別說明：專案未內嵌 Windows 系統字型（如微軟正黑體），那類字型不允許再散布。

`ui/menu_theme.tres` 是專案中唯一的 `.tres` 資源檔。

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
| OpenAI ChatGPT Images 2.0（`gpt-image-2`） | 美術素材生成，含以 NOXCAT 官方素材為參考圖重新生成黑貓角色（見第 3 節與 3.1） |
| OpenAI ChatGPT | 開發期的設計討論、程式與素材處理流程諮詢 |
| OpenAI Codex | 撰寫 [`tools/generate_dog_sfx.js`](tools/generate_dog_sfx.js) 音效合成腳本（見第 4.1 節） |
| Anthropic Claude Code | 部分程式碼撰寫、專案文件與匯出流程協助。相關 commit 於訊息中標註 `Co-Authored-By` |

主辦方原訂提供的 OpenAI Pro 方案與 API 額度至繳交前尚未開通，因此上述素材生成使用團隊成員的自有帳號完成，未動用贊助額度，遊戲執行時亦未呼叫任何 OpenAI API。

---

## 授權總結

- **程式碼、關卡資料、程式化合成音效**：MIT License，Copyright (c) 2026 水返腳(2).png (Team T045)，見 [LICENSE](LICENSE)
- **美術素材（原創部分）**：AI 生成後由團隊後製，依 OpenAI 使用條款隨本專案 MIT 散布
- **NoxCat 黑貓角色**：NOXCAT 官方 IP 之衍生形象，**權利由 NOXCAT 保留**，不適用 MIT。活動後續發布須取得 NOXCAT 書面同意（見第 3.1 節）
- **三個 Pixabay MP3**：Pixabay Content License，從未使用、從未散布，已於繳交前自儲存庫移除
- **Godot Engine**：MIT License，版權歸 Godot Engine contributors
