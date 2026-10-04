# 開發測試

在 macOS 使用 `python3 tests/test_publish.py`。Python 僅供開發測試，不是學員發布依賴。測試使用明確假的 `workshop_test_credential_0123456789`，僅連本機 bare Git repository，不送外部服務。

測試資料在系統臨時資料夾建立並清除，不接觸學員原檔。mock 以 PATH 內的 curl、git wrapper 注入，正式腳本未加入可任意變更 API host 的測試開關。Windows 實機測試見補充教學的核對清單。

## Windows PowerShell 5.1

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/test_windows.ps1 -OutputPath tests/WINDOWS_RESULTS.json
```

預設執行 19 項隔離測試，使用真實 Git 與假的測試字串，HTTP／Git 缺失以 PowerShell 函式模擬；不讀取真正 PAT。測試暫存目錄保留供除錯，與學員工作區分離。測試程式是 UTF-8 BOM，以便 Windows PowerShell 5.1 正確解析中文字元。

要加測遠端分歧，提供自己授權的公開示範 repo：`-DivergenceOwner 帳號 -DivergenceRepo 專案`。此案例只執行公開 ls-remote／fetch，API 身分回應仍為模擬，不執行 push；檢查 HEAD 與網站檔案不變。換行檔名由 Git tree 物件建立，沒有假稱 Win32 可建立換行檔案。三種秘密副檔名各有獨立案例，其內容刻意不等於假 PAT。

教材檢查：`python tests/check_material.py`，檢查 22 張內嵌圖片、錨點、放大連結、兩個 ZIP 與來源內容一致，且不含 PAT 檔或金鑰格式。Python 仍僅為維護測試工具，發布只需要 PowerShell 與 Git。
