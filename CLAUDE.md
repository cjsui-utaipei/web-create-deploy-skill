# 維護重點

- 2.0 工作區根名 web-create-deploy，網站須為直接子資料夾。PAT 只由父層讀取，根目錄不可 Git 初始化或發布。
- 公開資料不得有真正 PAT、Git credential helper、私人本機路徑或測試暫存。starter 不放假 PAT。
- macOS 測試：python3 tests/test_publish.py。Python 僅供開發測試，學員發布不需要。
- Windows 11／PowerShell 5.1 已於 2026-10-04 實測；結果與模擬範圍見 TEST_REPORT.md。使用 tests/test_windows.ps1 重跑，不把 macOS harness 當作 Windows 實測。
- 教材內容檢查：python tests/check_material.py。保留既有 14 張圖片；Windows 真實畫面新增 8 張。Codex 視窗截圖仍待人工補上，不以模擬畫面代替。
- 修改 scripts 後同步內嵌教學的 Skill ZIP；修改教材後更新 README 與測試報告。
- 分享教材入口只有 docs/新手完整圖解教學.html，保留真實 GitHub 截圖。歷史 v1.x 的同層 PAT 做法不適用新版。
