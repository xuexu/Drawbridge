@echo off
chcp 65001 >nul
title Drawbridge 一键启动

rem 双击本文件即可。用 Bypass 绕过默认禁止运行脚本的策略，否则会报"无法加载文件"。
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start-windows.ps1" %*

if errorlevel 1 pause
