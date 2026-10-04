# 發布機制 2.0.0

macOS 使用 Bash 3.2、curl、git、plutil；舊版 plutil 無法取值時使用系統 JXA JSON fallback，不需 jq、Python 或 Node。Windows 使用 PowerShell 5.1 與 Git for Windows，HTTP 由 .NET 提供，不要求額外套件。

PAT 只送到 api.github.com 及 github.com Git 認證。macOS 使用私有暫存資料夾與限定 github.com 的 credential helper；Windows 使用限制目前使用者 ACL 的暫存 credential-store。結束及例外清除暫存憑證，作業系統強制終止或斷電仍可能留下暫存資料，不能保證斷電清除。公開網站驗證不附 PAT。

`.git/pages-beginner-state` 保存 owner 與 repo，不含金鑰，用於重跑及更新。remote 保持 HTTPS 普通網址；不改 global Git。初次建立 public repo，main 根目錄發布並加入 .nojekyll；更新需遠端可快轉，否則中止。`.git/pages-backups` 保存原 .gitignore，不會進版控。

成功條件為 Pages latest build 的 commit 等於本機 SHA，狀態 built，且公開首頁 HTTP 200、內容與本次 Git commit 的 index.html 完全相同（避免 Windows CRLF 換行誤判）。90 秒內未確認，回傳 pending；不把舊站的 HTTP 200 當作本次成功。API request 有 timeout，因此總耗時可能比輪詢秒數長。

dry-run 不連 GitHub、不修改專案；只驗證 Git、入口、金鑰檔、秘密、檔案大小並提供名稱與 ignore 規劃。不能藉 dry-run 宣稱 PAT 有效或名稱未被使用。

限制：不支援 worktree、非 main 既有分支、非本 Skill 管理的 origin、symlink、custom domain、框架建置或私人 Pages。只取消秘密檔追蹤不會清除歷史，因此歷史存在敏感檔名或目前 PAT 時停止。未知其他秘密仍需 Agent 先檢查網站發布範圍。

網站必須是 web-create-deploy 的直接子資料夾。PAT 由上一層讀取，根目錄與兄弟網站不在 Git 操作範圍。網站內有 github_pat.txt 時拒絕發布。
