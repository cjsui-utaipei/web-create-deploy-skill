---
name: github-pages-beginner
description: Publish or update a local static HTML website on public GitHub Pages using a PAT stored in the parent web-create-deploy workspace. Use when a beginner asks to publish HTML to GitHub Pages or update that site. Supports macOS and Windows 11; excludes backend and framework build deployment.
---

# GitHub Pages 新手發布

使用者只需準備網站與 `github_pat.txt`，說「幫我發布網站」或「幫我更新網站」。發布要求授權建立 public repository、上傳網站與啟用 Pages；沿用相同專案更新，不逐步要求確認。網站與原始碼會公開，第一次發布前以一句話告知。只發布使用者指定的網站資料夾。

## 工作區結構

```text
web-create-deploy/
  AGENTS.md
  github_pat.txt
  web-app-oooxxx/
    index.html
  web-app-xxxxsss/
    index.html
```

PAT 僅放在 web-create-deploy 根目錄。每個直接子資料夾各自是一個網站和一個 repository；根目錄不可 git init 或發布。腳本只讀網站上一層的 PAT，不向上搜尋其他資料夾。若使用者尚未指定網站且有多個網站，先詢問要發布哪一個。
初始化工作區時，將 [AGENTS.md 範本](assets/AGENTS.md) 複製到根目錄；已有 AGENTS.md 則保留原文並合併必要規則。建立根目錄 .gitignore，至少排除 github_pat.txt、github_pat*、.env、.env.*。不要建立空白 PAT 假裝完成設定。所有新網站放在 web-app-具體名稱 子資料夾。不要把舊的網站內 PAT 留著或直接上傳；請使用者將它移到父資料夾。

## 執行

1. 確認目前環境能讀取本機專案、執行 shell 且連上 GitHub。純聊天模式無法執行；引導切換能操作本機資料夾的 Codex 工作環境。
2. 讀取 [網站檢查](references/site-preflight.md)，檢查網站入口與路徑。不要讀出 PAT，不要 `cat`、預覽、截圖或把 PAT 傳給模型；由腳本內部讀取即可。不要搜尋其他專案的憑證。
3. 若無金鑰，顯示 [PAT 設定](references/pat-setup.md)，等使用者存好後繼續。缺 Git 時依 [環境與錯誤](references/error-codes.md) 引導安裝，僅安裝此依賴需要另外取得同意。
4. 先執行 dry-run。將下列 SCRIPT 換成此 Skill 安裝目錄的 scripts 路徑，PROJECT 換成網站絕對路徑，全部路徑加引號。

macOS：
```bash
bash "SCRIPT/publish.sh" --project-dir "PROJECT" --dry-run
bash "SCRIPT/publish.sh" --project-dir "PROJECT"
```

Windows 11 原生 PowerShell：
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "SCRIPT\publish.ps1" -ProjectDir "PROJECT" -DryRun
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "SCRIPT\publish.ps1" -ProjectDir "PROJECT"
```

5. 使用者指定 repo 名才傳 `--repo-name` 或 `-RepoName`。預設從資料夾產生名稱，純中文改用 `my-webpage`，撞名另建尾碼。
6. 按回傳 code 對照錯誤表。不要直接呈現 stack trace。不要把網路錯誤或限流說成 Token 無效。
7. `ok: true` 且 `pages_status: built` 才回報成功。`pending` 說「已送出，目前仍在部署」，保留網址，之後重跑同一腳本驗證。不要無限輪詢。

## 輸出

首次成功：「網站發布成功。你的網站：[開啟網站](實際 pages_url)。以後修改內容後，說『幫我更新網站』即可。」另附 repository_url。
更新成功：「網站已更新，網址不變：[開啟網站](實際 pages_url)。」

## 邊界

- 不碰 global Git、帳號設定、SSH、billing、DNS、custom domain、workflow。不可 force push、刪除 repo 或自動改寫歷史。
- 已有非本 Skill 管理的 remote，腳本安全停止。不要只因 owner 相同就當作本次授權發布目標。
- 原始檔修改前，快照到專案外的本機資料夾；不可把備份跟著發布。不要讓測試、教材、PAT、.env 進網站 repository。
- 秘密已在歷史：停止上傳，請使用者撤銷並重建 PAT。`git rm --cached` 無法移除歷史，不可用它假裝修好。
- 不把這台講師電腦的帳號、作者名、雲端路徑或通知設定寫入學員專案。

機制與限制見 [architecture](references/architecture.md)。
