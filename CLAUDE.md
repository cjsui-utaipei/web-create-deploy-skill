# 維護重點

- 2.0 工作區根名 web-create-deploy，網站須為直接子資料夾。PAT 只由父層讀取，根目錄不可 Git 初始化或發布。
- 公開資料不得有真正 PAT、Git credential helper、私人本機路徑或測試暫存。starter 不放假 PAT。
- macOS 測試：python3 tests/test_publish.py。Python 僅供開發測試，學員發布不需要。
- Windows PowerShell 5.1 沒有在此 Mac 執行，不得宣稱已實機驗證。參考 docs/Windows11-測試與補圖.md。
- 修改 scripts 後同步內嵌教學的 Skill ZIP；修改教材後更新 README 與測試報告。
- 分享教材入口只有 docs/新手完整圖解教學.html，保留真實 GitHub 截圖。歷史 v1.x 的同層 PAT 做法不適用新版。
