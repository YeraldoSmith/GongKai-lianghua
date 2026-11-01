@echo off
REM 学生量化管理系统 · Win11 便携启动脚本（双击运行，无需安装 Node / Docker）
REM 注意：不要把 lianghua-server.exe 单独移出这个文件夹，它需要同目录下的 web 文件夹提供网页。
cd /d %~dp0
if not defined PORT set PORT=8787
if not defined STATIC_DIR set STATIC_DIR=%~dp0web
if not defined DB_FILE set DB_FILE=%~dp0data\lianghua.db
if not exist data mkdir data
echo.
echo 学生量化管理系统正在启动……
echo 启动完成后，用浏览器打开 http://localhost:%PORT%
echo 演示账号在登录页直接点名字登录；正式使用前请先读上层目录的 DEPLOY-WIN11.md
echo 按 Ctrl+C 可停止服务。
echo.
lianghua-server.exe
pause
