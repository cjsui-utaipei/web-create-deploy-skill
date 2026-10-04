# T01–T30 驗收對照

自動測試採真實 Git、本機 bare remote、模擬 curl，沒有連線 GitHub。Windows 11 必須另行執行實機清單。

| 原規格 | 對應與狀態 |
|---|---|
| T01 | macOS 完整流程 mock PASS；GitHub live NOT RUN |
| T02 | Windows 程式碼已提供；Windows live NOT RUN |
| T03 | Windows 安裝引導已寫；執行 NOT RUN |
| T04 | test_missing_git PASS；Apple 安裝視窗 NOT RUN |
| T05–T08 | missing、empty、invalid、permission PASS |
| T09–T10 | publish_update_unchanged 檢查追蹤檔、remote 與 config PASS |
| T11 | ignore PASS |
| T12–T13 | publish_update_unchanged PASS |
| T14–T15 | collision、chinese_name PASS |
| T16–T17 | 所有案例使用中文加空格路徑；unicode PASS |
| T18–T20 | 已備根路徑與外部網址 fixtures；Agent 網頁修正行為 NOT RUN |
| T21 | missing_entry 腳本攔截 PASS；Agent 建入口行為 NOT RUN |
| T22 | 已定義詢問首頁策略；互動驗收 NOT RUN |
| T23 | large PASS |
| T24–T25 | unrelated_remote、diverged PASS |
| T26–T27 | update、wrong_source PASS |
| T28–T29 | build_fail、network PASS |
| T30 | 每次輸出不含假金鑰、temp 清理、tracked files、remote/config 檢查 PASS；無真實 PAT 可掃描 |

額外測試：首次 push 失敗重試、CRLF、BOM、symlink、secret copy、secret history、rate limit、舊站內容、API 409 與 422、dry-run 無修改。

模擬涵蓋 GET /user、POST /user/repos、GET/POST/PUT Pages、GET latest build，以及 200、201、204、401、403、404、409、422。HTTP mock 替換 curl 可執行檔，不是遠端 HTTPS server，不代表 TLS、GitHub 權限或真實建置已驗收。
