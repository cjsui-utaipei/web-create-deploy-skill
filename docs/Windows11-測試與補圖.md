# Windows 11 接續測試與講義補圖

2026-10-04 已完成 Windows 11／PowerShell 5.1 實測：20 項隔離測試通過，兩站真實發布與第一站同網址更新通過。整合講義已補 8 張 Windows 真實截圖；Codex 安裝／叫用視窗仍待人工補圖。詳細證據、模擬範圍與未執行項目以 TEST_REPORT.md 為準。

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
| GitHub 網址安裝 | SKILL.md、scripts、references、assets 完整 | PASS，10 檔一致 |
| UTF-8 PAT | 支援換行及 BOM | PASS，隔離檔案編碼案例；未操作記事本 |
| 指定根目錄發布 | WORKSPACE_LAYOUT，沒有建立 repo | PASS |
| PAT 放網站內 | TOKEN_INSIDE_SITE，沒有上傳 | PASS，假 token |
| 第一次發布 oooxxx | 網址可開啟，repo 無 PAT、AGENTS.md、另一網站 | PASS，真實 built 與首頁比對 |
| 更新 oooxxx | 網址不變，內容已更新 | PASS，真實發布 |
| 發布 xxxxsss | 另一 repo 與網址 | PASS，真實發布 |
| 缺 Git | GIT_MISSING | PASS，模擬；未移除已安裝 Git |
| token 無效 | TOKEN_INVALID，不顯示憑證 | PASS，格式案例與 HTTP 401 模擬 |
| 網路失敗 | NETWORK_ERROR，不修改檔案 | PASS，模擬 |
| 中文／換行秘密路徑 | .env、.pem、.key 各自阻擋 | PASS，6 個獨立歷史案例 |
| staged changes／非管理 remote／遠端分歧 | 安全停止 | PASS，詳見測試報告的模擬範圍 |

更新 TEST_REPORT.md 時區分 mock、靜態檢查與真實 Windows 測試，並更新 README.md 的限制。
