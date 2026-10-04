# 開發測試

在 macOS 使用 `python3 tests/test_publish.py`。Python 僅供開發測試，不是學員發布依賴。測試使用明確假的 `workshop_test_credential_0123456789`，僅連本機 bare Git repository，不送外部服務。

測試資料在系統臨時資料夾建立並清除，不接觸學員原檔。mock 以 PATH 內的 curl、git wrapper 注入，正式腳本未加入可任意變更 API host 的測試開關。Windows 實機測試見補充教學的核對清單。
