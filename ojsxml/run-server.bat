@echo off
pushd %~dp0
php -c "%~dp0php-cli.ini" -S localhost:8000
popd