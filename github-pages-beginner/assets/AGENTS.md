# web-create-deploy 工作區

這是多個靜態網站的工作區，不是單一 Git repository。

- 每個 web-app-* 直接子資料夾是一個網站，入口為 index.html，各自對應獨立 GitHub repository。
- github_pat.txt 只放本層，由發布腳本讀取；不得輸出、複製到網站、提交、上傳或放進教材。
- 不可在本層 git init、git add、commit 或 push。Git 操作須以指定網站為工作目錄。
- 使用 $github-pages-beginner 發布。先 dry-run，再依使用者授權發布，網址驗證完成才回報成功。
- 有多個網站而使用者未指定時，先問網站名稱，不要一次發布全部。
- 修改前備份到網站外；不讓備份、私人文件或其他網站進入發布範圍。
