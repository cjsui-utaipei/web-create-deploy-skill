# Windows 11 接續測試與講義補圖

目前只有 macOS 真實畫面；此檔是待執行測試，不代表 Windows 已通過。

## 在 Windows Codex 貼上

先依 INSTALL-PROMPT.md 安裝新版 Skill。請在「文件」建立 web-create-deploy，並依下列流程逐項測試。保留既有檔案，PAT 只由腳本讀取，不輸出到終端機、對話或截圖。每個結果記錄 Windows 版本、PowerShell 版本、Git 版本、Skill commit、實際步驟與結果。遇到錯誤先保存去除秘密的錯誤碼與重現步驟。

## 需要的真實截圖

1. win01-workspace.png：檔案總管顯示 web-create-deploy 內的兩個網站、AGENTS.md、github_pat.txt，只顯示檔名。
2. win02-extensions.png：「檢視 → 顯示 → 副檔名」，確認不是 github_pat.txt.txt。
3. win03-site.png：進入 web-app-oooxxx，顯示 index.html；不能有 PAT。
4. win04-codex.png：Codex 已選取 web-create-deploy，能找到 Skill。對話不含 PAT。
5. win05-result.png：第一次發布成功，顯示 repository_url 與 pages_url。
6. win06-update.png：修改標題後，原網址顯示新內容。

圖片放 docs/screenshots/。補入 docs/新手完整圖解教學.html 的 Windows 區塊，保留 Mac 圖。不能以合成畫面替代實機截圖。

## 驗收表

| 測試 | 預期 | 實測 |
|---|---|---|
| GitHub 網址安裝 | SKILL.md、scripts、references、assets 完整 | 待測 |
| UTF-8 PAT | 支援記事本換行及 BOM | 待測 |
| 指定根目錄發布 | WORKSPACE_LAYOUT，沒有建立 repo | 待測 |
| PAT 放網站內 | TOKEN_INSIDE_SITE，沒有上傳 | 待測 |
| 第一次發布 oooxxx | 網址可開啟，repo 無 PAT、AGENTS.md、另一網站 | 待測 |
| 更新 oooxxx | 網址不變，內容已更新 | 待測 |
| 發布 xxxxsss | 另一 repo 與網址 | 待測 |
| 缺 Git | 引導安裝 Git for Windows | 待測 |
| token 無效 | TOKEN_INVALID，不顯示憑證 | 待測 |
| 網路失敗 | 可安全重試，不 force push | 待測 |

更新 TEST_REPORT.md 時區分 mock、靜態檢查與真實 Windows 測試，並更新 README.md 的限制。
