# 發布前網站檢查

只對靜態網站進行。若需要伺服器、資料庫、私密 API key，說明 GitHub Pages 無法直接提供該功能，不要把 key 寫入 JavaScript。

## 入口

- 有 index.html：沿用，檢查本機預覽。
- 只有一個 HTML：保留原檔，建立 index.html 重新導向原檔，URL 要正確編碼。
- 多個 HTML：檢視內容判斷；不明確才問哪個是首頁。
- 沒有 HTML：回報尚缺首頁，不建立空遠端。

## 路徑

檢查 HTML 的 src、href、srcset、CSS url()、JS fetch 與 import。專案網址帶 repository 子路徑，`/style.css` 會指向網域根目錄。依引用檔所在層級計算相對路徑：根目錄 index.html 可用 `./style.css`，pages/about.html 應用 `../style.css`，不要把所有前導斜線盲改成 `./`。

`https:`、`http:`、`//cdn`、`data:`、`mailto:`、`tel:`、`#anchor` 不修改。動態運算或 API 路徑不要猜測。先備份到網站資料夾外，再逐處修正並本機確認 CSS、圖片及連結；發布後再開網址查驗。

腳本負責入口存在、大小、秘密、symlink、Git 與部署驗證；HTML 語意判斷和路徑修正由 Codex 完成，單獨執行腳本不會自動重寫網站。
