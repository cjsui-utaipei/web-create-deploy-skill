# 只設定一次：GitHub 發布金鑰

1. 登入你自己的 GitHub 帳號。
2. 右上角頭像 → Settings → Developer settings → Personal access tokens → Tokens (classic)。亦可開啟 https://github.com/settings/tokens 。
3. Generate new token → Generate new token (classic)，依 GitHub 要求完成身分驗證。
4. Note 填 `pages-workshop`；Expiration 可選 90 days；勾 `repo`，不勾 delete_repo 或 workflow。
5. 按 Generate token，複製產生的金鑰。只在這個畫面顯示一次，遺失就重建。
6. 用純文字編輯器把金鑰存進web-create-deploy 根目錄的 `github_pat.txt`，一行、無引號，不貼到聊天。
7. 告訴 Codex「好了，幫我發布網站」。

Classic PAT 的 repo 權限範圍較廣，也可能存取此帳號的私人 repository。依本課程採用此方式以完成 Pages API 設定；上課可使用專用練習帳號，課後在相同設定頁撤銷金鑰。PAT 檔仍是本機明文，不要放進共享資料夾、寄送 ZIP 或截圖。

macOS：「文字編輯」先選「格式 → 製作純文字」，再存檔。Windows 11：記事本另存新檔，檔案類型選「所有檔案」，編碼 UTF-8。確認不是 `.rtf` 或 `github_pat.txt.txt`。

來源：https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
Pages Classic PAT scope：https://docs.github.com/en/rest/pages/pages#create-a-github-pages-site
