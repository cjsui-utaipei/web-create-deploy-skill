# 2.0 測試報告

## 2026-10-04 Windows 實測更新（教材 2.0.1）

環境：Windows 11 教育版 10.0.26200（build 26200）、Windows PowerShell 5.1.26100.9444、Git 2.41.0.windows.3、codex-cli 0.160.0。桌面 App 版本未另行取得。起始程式碼 commit：`f90b52db776022f548a64751b6943437dc09e394`。發布腳本沒有修改，Skill 仍為 2.0.0。

### 通過

- **安裝實測**：以內建 skill-installer 從公開 GitHub 下載；10 個檔案與來源一致（忽略 Git checkout 的 CRLF／LF 差異），SKILL.md、scripts、references、assets 齊全。使用者下一則「繼續」時，環境提供的技能清單已列出 github-pages-beginner，並讀取安裝路徑的 SKILL.md，依其指示執行。
- **Windows 隔離測試 20/20**：詳見 `tests/WINDOWS_RESULTS.json`，由 Windows PowerShell 5.1 執行 `tests/test_windows.ps1`。包含中文及空白路徑 dry-run、UTF-8 BOM／CRLF、根目錄、網站內 PAT、缺少／空白／格式錯誤 PAT、缺入口、staged changes，以及中文與換行路徑中的 `.env`、`.pem`、`.key` 各自獨立的歷史檢查。假 token 不會出現在輸出，負向案例檢查檔案不變與 exit code。
- **模擬範圍**：20 項中，HTTP 401、網路錯誤、Git 缺失及 unmanaged remote 的身分驗證使用 PowerShell 函式模擬。遠端分歧使用真實 Git 讀取公開示範 repo，API 身分／repo 回應為模擬；只 fetch，不 push，原 HEAD 與網站檔案不變。未把這些列為真實 GitHub 失敗情境。
- **換行路徑**：Win32 無法直接建立換行檔名，案例用 `git mktree`／`commit-tree` 建立可被 `git log --all -z` 讀取的真實歷史物件。秘密檔內容與測試 PAT 不同，不依賴內容掃描掩蓋路徑缺陷。
- **真實發布**：使用父層 PAT，腳本先以 `/user` 確認帳號 cjsui-utaipei；首次發布第一站、修改標題後更新第一站、發布第二站，三次皆回傳 `ok: true`、`pages_status: built`。Pages 最新 build commit 與本次 commit 相符，公開首頁逐位元組比對通過。
- **發布邊界**：兩站各自只有 `.gitignore`、`.nojekyll`、`index.html`，沒有父層 PAT、AGENTS.md、兄弟網站或備份。workspace 根目錄沒有 `.git`。兩個遠端 HEAD 與本機相同；第二站發布後再確認第一站內容不變。
- **教材**：保留原有 13 張 GitHub 圖與 macOS 圖，新增 8 張 Windows 真實截圖，共 22 張。22 張皆可載入、21 個放大連結逐一開啟成功，目錄錨點有效。1280px 與 390px 視窗無水平溢出。兩個下載按鈕實際產生 ZIP，下載檔逐位元組與內嵌資料相同；ZIP 完整且檔案與來源相同，不含 github_pat.txt。檢查程式：`tests/check_material.py`。

| 真實操作 | Commit | 結果 |
|---|---|---|
| 第一站首次發布 | `914a9be96210a1138bd231b4da53b07b96d228a6` | built，公開首頁相符 |
| 第一站更新 | `8b065eb4d0ec00d0f87d50c984f0f8c62d6a0f51` | built，同網址，新標題 |
| 第二站發布 | `93fc5ce6292f319225b1ebbd3b872176f7975fcd` | built，獨立 repo 與網址 |

第一站：[repo](https://github.com/cjsui-utaipei/web-app-oooxxx)／[Pages](https://cjsui-utaipei.github.io/web-app-oooxxx/)。第二站：[repo](https://github.com/cjsui-utaipei/web-app-xxxxsss)／[Pages](https://cjsui-utaipei.github.io/web-app-xxxxsss/)。結構化證據及首頁 SHA-256：`tests/WINDOWS_LIVE_RESULTS.json`。

### 失敗與工具限制

發布與上述 20 項測試沒有失敗。外部 Chrome 桌面擷取因工具無法可靠辨識 URL 而被停止；改用可辨識 URL 的 Codex 內建瀏覽器完成公開網頁擷取。瀏覽器 download 事件等待曾逾時，後續確認兩個 ZIP 實際已下載且內容完全相符，因此下載功能判定通過，事件監聽不作為成功依據。

### 未執行／待人工

- Codex 工作區與 Skill 安裝／叫用結果的桌面截圖仍缺 1 張；Windows Computer Use 技能禁止自動操作 ChatGPT 桌面介面。詳見 `docs/screenshots/WINDOWS-20261004.md`，不以合成圖代替。
- 未重新在 macOS 執行既有 34 項 harness，以下歷史結果原樣保留。
- 未實際移除系統 Git、切斷網路或送出失效的真 PAT；相關分類為隔離模擬。UTF-8 BOM／換行由檔案 API 建立測試檔，沒有將真正 PAT 貼入記事本操作。
- 真實 repo 撞名未發生，不宣稱已做真實撞名測試。

## 原有 macOS 階段紀錄（保留；以下「待測」為當時狀態）

2026-10-04：macOS 34 項模擬整合測試 PASS，使用真 Git、本機 bare repo 與模擬 GitHub HTTP；不等同真實 GitHub 發布。Skill 官方結構驗證 PASS。

新增驗證：拒絕 workspace 根目錄、拒絕網站內 PAT、父層 PAT 符號連結、兄弟網站與根 AGENTS.md 不提交。沿用 28 項首次發布、重試、更新、秘密掃描、衝突與編碼測試。

Windows PowerShell 5.1：僅靜態檢查，實機測試及截圖待 Ron 在 Windows 電腦執行。macOS Finder 截圖已完成。

互盲審查：A 對父層 PAT 邊界 PASS；B 找到 Git 轉義中文路徑導致歷史 .env 漏檢。主工作階段依可重現案例裁定修正，兩版改為 NUL 路徑解析，補中文與換行目錄回歸測試。

修正後 B 複審 PASS；獨立執行中文、換行與發布更新測試通過。
實際從公開 GitHub repo 以 Codex skill-installer 下載至隔離目錄成功，安裝後每個 Skill 檔案與發布版本相同。教材 14 張有效圖片載入、無水平溢出，兩個內嵌 ZIP 完整且無 PAT 檔。Skill 的真實 Pages 發布仍未執行，未將程式碼 repo 的 push 誤列為 Pages 測試。
