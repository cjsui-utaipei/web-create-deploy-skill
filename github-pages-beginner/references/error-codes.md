# 環境與錯誤處理

| Code | 對新手說明與處理 |
|---|---|
| GIT_MISSING、GIT_INSTALL_REQUIRED | 還缺發布工具 Git，只需安裝一次。先詢問安裝同意。Windows 偵測 winget，使用 `winget install --id Git.Git -e --source winget`，安裝後重新找 git.exe，必要才重開 Codex。失敗改用 https://git-scm.com/download/win 。Mac 用 `xcode-select --install` 開啟 Apple 安裝流程，使用者完成後重試。不要為測試移除 Git。 |
| TOKEN_MISSING | 依 pat-setup.md 設定發布金鑰。 |
| TOKEN_EMPTY、TOKEN_INVALID | 金鑰空白、格式錯誤、失效或過期。重新建立並存入純文字檔。 |
| TOKEN_PERMISSION | GitHub 拒絕此操作；確認 classic repo 權限、帳號與組織政策。不要自動擴權。 |
| RATE_LIMITED | GitHub 暫時限制請求，稍後再試。 |
| NETWORK_ERROR | 目前無法連上 GitHub，確認網路再重試。 |
| SITE_ENTRY_MISSING | 依 site-preflight.md 補入口，不建立空 repo。 |
| FILE_TOO_LARGE | 有檔案達 100 MiB，先處理大型檔案；不自動導入 LFS。 |
| SECRET_IN_HISTORY、SECRET_IN_FILES、SECRET_STAGED、TOKEN_IN_CONFIG | 發現金鑰或秘密資料可能被公開，已停止。不要顯示內容。若曾公開或提交 PAT，撤銷重建，另行處理歷史。 |
| REPO_CONFLICT、UNMANAGED_REMOTE、ACCOUNT_MISMATCH | 專案與目前帳號或遠端不一致，先確認正確專案；不覆寫遠端。 |
| STAGED_CHANGES | 有使用者已暫存的變更，停止以免混入本次發布。 |
| REMOTE_DIVERGED | GitHub 上有本機尚未包含的版本，停止更新，另行協助合併。 |
| CUSTOM_PAGES_CONFIG | 發現自訂網址或 workflow，不自動改成預設。 |
| REPO_CREATE_FAILED | 建立專案未完成；檢查 GitHub 狀態與名稱，保留本機版本。 |
| GIT_INIT_FAILED、GIT_COMMIT_FAILED、GIT_PUSH_FAILED、GIT_OPERATION_FAILED | Git 操作未完成，保留所有本機檔案；由 Agent 檢查不含秘密的狀態。 |
| PAGES_CREATE_FAILED、PAGES_CONFIG_FAILED | 網站已上傳但 Pages 設定未完成，稍後重試同一專案。 |
| PAGES_BUILD_FAILED | GitHub 建置未通過，不宣稱上線成功。 |
| PAGES_BUILD_PENDING | 尚未確認此次版本上線，稍後重跑；網址保持不變。 |
| SITE_HTTP_FAILED | 網站回應異常，稍後重試並檢查部署。 |
| SYMLINK_UNSUPPORTED、TOKEN_FILE_UNSAFE、SITE_ENTRY_UNSAFE | 發現捷徑或符號連結，改成網站需要的實體檔案，避免發布資料夾外的內容。 |
| ARGUMENT_ERROR、PROJECT_MISSING、REPO_NAME_INVALID、API_RESPONSE_INVALID、INTERNAL_ERROR | 由 Agent 修正執行參數或檢查相容性，勿要求新手理解程式錯誤。 |

腳本不自行安裝軟體，也不永久修改 PowerShell execution policy。對腳本未知錯誤不輸出原始 exception，以免帶出 token。

## 工作區結構錯誤
- WORKSPACE_LAYOUT：請選 web-create-deploy 下面的一個網站子資料夾，不能發布根目錄。
- TOKEN_INSIDE_SITE：網站內含 github_pat.txt，請先移到 web-create-deploy 根目錄。
- TOKEN_FILE_UNSAFE：PAT 不可為符號連結或 Windows 連接點。
