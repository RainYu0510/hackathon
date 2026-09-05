# 2026-09-05 匯出版第三關跑成第四關 —— 重複 UID

同學測試 itch.io 上的 Web 版，回報「自然玩到第三關後好像有第四關出現」，主選單
「選擇關卡 → 第三關」進去也一樣。畫面上那句 `LEVEL 04 — lure the angry monster into
the wall (one charge only)` 就是 `levels/Level04.gd` 的 HUD 標籤 —— 第三關的腳本被
換成了 Level04 的。

團隊沒有要做第四關。`Level04.gd` / `Level04.tscn` 是第三關的早期粗胚版（破牆即過關），
`3198621` 把它重做成 Level03 之後就留在 repo 裡沒刪。

## 為什麼編輯器裡看不出來

F5 玩起來完全正常，只有匯出版會壞。這是判斷方向的關鍵，也是這個 bug 能活到打包
之後才被發現的原因。

`levels/Level03.tscn` 是這樣寫的：

```
[gd_scene load_steps=2 format=3]
[ext_resource path="res://levels/Level03.gd" type="Script" id="1"]
```

`[ext_resource]` 只有 `path`，**沒有 `uid=` 欄位**。編輯器載入文字 `.tscn` 時純粹照
path 解析，所以永遠正確。

匯出時 `.tscn` 會被轉成 binary `.scn`（存在 `.godot/exported/` 底下再打進 pck），
而 binary 格式的 ext_resource 是 `(type, path, uid)` 三元組 —— saver 會去查那個
path 的 UID 一起寫進去，loader 則**優先採用 UID、忽略 path**。文字版沒有的資訊，
二進位版憑空多出來了，這就是兩者行為分岔的地方。

## 成因

`levels/Level03.gd.uid` 與 `levels/Level04.gd.uid` 內容相同，都是
`uid://bjsflpbh254s1`。git 記錄得很清楚，`3198621` 移植第三關時是整份複製：

```
diff --git a/levels/Level04.gd.uid b/levels/Level03.gd.uid
similarity index 100%
copy from levels/Level04.gd.uid
copy to levels/Level03.gd.uid
```

一個 UID 只能對應一個路徑。`.godot/uid_cache.bin` 裡的映射是
`uid://bjsflpbh254s1 → res://levels/Level04.gd`，而 `res://levels/Level03.gd`
**完全沒有 UID 條目** —— 它在爭奪中輸掉了。

於是：`Level03.scn` 的 ext_resource path 寫著 `res://levels/Level03.gd`，內嵌 uid
寫著 `bjsflpbh254s1`，loader 拿 uid 去查、查到 `Level04.gd`，就載入了 Level04。

## 怎麼查到的

`.gdc` 是 tokenize 過的位元碼，字串常數在 pck 裡不是明文，`strings | grep "LEVEL 0"`
撈不到東西。改成直接讀 binary scene 的位元組：找到 ext_resource 的 path 字串
（Godot 的 binary string 格式是 `u32 長度（含結尾 null）` + bytes，**沒有對齊
padding**），緊接其後的 8 bytes 就是 little-endian 的 uid int64。

```
Level01.scn  ext path=res://levels/Level01.gd  uid_raw=2764859152220416019  -> uid://bfnk3dgl373d4
Level03.scn  ext path=res://levels/Level03.gd  uid_raw=3055603094455653554  -> uid://bjsflpbh254s1
Level04.scn  ext path=res://levels/Level04.gd  uid_raw=3055603094455653554  -> uid://bjsflpbh254s1
```

Level03 與 Level04 的內嵌 uid 逐位元組相同，`Level01` 的解碼結果與它的 `.uid`
sidecar 相符（用來確認解碼方式沒錯）。`ResourceUID` 的文字編碼是 base-34：餘數
0–24 對到 `a`–`y`，25–33 對到 `0`–`8`，`z` 與 `9` 不使用。

## 修法

刪掉 `levels/Level04.gd`、`Level04.gd.uid`、`Level04.tscn`。

全專案 `grep -rn "Level0[34]"` 確認過沒有任何檔案指向 `Level04.tscn`，只有
`Level04.tscn` 自己引用 `Level04.gd`，所以這是純粹的孤兒檔。刪掉之後
`uid://bjsflpbh254s1` 只剩 `Level03.gd` 一個持有者，內嵌 UID 自然解析正確。

沒有選「給 Level03.gd 換一個新 UID、保留 Level04」，因為 Level04 本來就是已經被
取代的死程式碼，留著它等於留著同一個坑的複製來源。

刪除還有一個附帶好處：萬一 UID 解析之後又出什麼意外，載入會變成「找不到腳本」的
明確錯誤，而不是靜默跑出一個錯誤的關卡 —— 後者才是這次難查的真正原因。

## 之前判斷錯了

這組重複 UID 在先前的原始碼稽核就發現過，當時寫進 README 限制節的結論是「每次
`godot --headless --import` 會出現一則匯入警告，**不影響執行**」。那個結論是錯的，
它就是這個 bug 的成因。同一節裡「`Level04` 沒有任何路徑指向它，正常遊玩不會遇到」
在 path 層面成立，但在匯出版裡它會被 UID 劫持而執行到。兩條敘述都已改寫。

教訓：`--import` 印出來的 UID duplicate 訊息不是可以放過的雜訊。

## 這輪沒做

- 沒動 `Level03.gd` / `Level03.tscn` 的任何一個字元，關卡幾何與機制完全沒碰
- 沒刪 `Level03_PLACEHOLDER.tscn` / `Level05_PLACEHOLDER.tscn`（同樣是孤兒，但沒有
  UID 撞號，不在這次範圍）
- 沒修 `p2_left` / `p2_right` 的 keycode、沒補 `ChargeMonster` 的 `HurtBox`、沒動音效

## 驗證

修正後重跑 `--import` 與兩個平台的匯出，用查 bug 時同一套方法回頭驗：

- `.godot/uid_cache.bin`：`uid://bjsflpbh254s1` 改為映射到 `res://levels/Level03.gd`
- 重新匯出的 `Level03.scn` 內嵌 uid 仍是 `3055603094455653554`，而該 uid 現在指向
  `Level03.gd`
- `.godot/exported/` 底下不再有 `Level04.scn`，pck 裡不再有 `res://levels/Level04.gd`
- 全專案 `.uid` 重複掃描為零
- Chrome 開本機 Web 版，選關進第三關要看到
  `LEVEL 03 - lure the monster away, then let it charge into the cracked wall`
