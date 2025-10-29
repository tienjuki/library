#!/bin/bash
#
# run_app.sh - Quản lý ứng dụng Java Spring Boot WAR
# Dùng: /app/run_app.sh <app_name> {start|stop|status|restart|deploy|remove}
#

APP_BASE="/app"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <app_name> {start|stop|status|restart|deploy|remove}"
  exit 1
fi

APP_NAME="$1"
ACTION="$2"
APP_DIR="${APP_BASE}/${APP_NAME}"
CONF_FILE="${APP_DIR}/app.conf"
PID_FILE="/var/run/${APP_NAME}.pid"
LOG_FILE="/var/log/${APP_NAME}.log"

if [ ! -d "$APP_DIR" ]; then
  echo "❌ Không tìm thấy thư mục ứng dụng: $APP_DIR"
  exit 1
fi

if [ ! -f "$CONF_FILE" ]; then
  echo "❌ Không tìm thấy file config: $CONF_FILE"
  exit 1
fi

# Nạp cấu hình
source "$CONF_FILE"

if [ -z "$MAIN_CLASS" ] || [ -z "$PORT" ] || [ -z "$WAR_FILE" ]; then
  echo "❌ Thiếu cấu hình trong $CONF_FILE (cần MAIN_CLASS, PORT, WAR_FILE)"
  exit 1
fi

mkdir -p "$(dirname "$PID_FILE")" "$(dirname "$LOG_FILE")"

start_app() {
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "⚠️  $APP_NAME đang chạy (PID $(cat "$PID_FILE"))"
    return
  fi

  cd "$APP_DIR" || exit 1
  if [ ! -d "WEB-INF" ]; then
    echo "📦 Giải nén $WAR_FILE..."
    jar xvf "$WAR_FILE" >/dev/null
  fi

  echo "🚀 Khởi động $APP_NAME (port $PORT)..."
  nohup java -Dserver.port="$PORT" -cp "WEB-INF/classes:WEB-INF/lib/*" "$MAIN_CLASS" >>"$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"
  echo "✅ $APP_NAME started (PID $(cat "$PID_FILE"))"
}

stop_app() {
  if [ ! -f "$PID_FILE" ]; then
    echo "⚠️  $APP_NAME chưa chạy"
    return
  fi

  pid=$(cat "$PID_FILE")
  echo "🛑 Dừng $APP_NAME (PID $pid)..."
  kill "$pid" 2>/dev/null || true
  rm -f "$PID_FILE"
  echo "✅ $APP_NAME stopped"
}

status_app() {
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "🟢 $APP_NAME đang chạy (PID $(cat "$PID_FILE"))"
  else
    echo "🔴 $APP_NAME đã dừng"
  fi
}

deploy_app() {
  echo "📦 Triển khai lại $APP_NAME..."
  stop_app
  cd "$APP_DIR" || exit 1
  rm -rf WEB-INF META-INF 2>/dev/null || true
  echo "📂 Giải nén lại $WAR_FILE..."
  jar xvf "$WAR_FILE" >/dev/null
  start_app
  echo "✅ Deploy hoàn tất cho $APP_NAME"
}

remove_app() {
  echo "🧹 Gỡ bỏ $APP_NAME..."
  stop_app
  cd "$APP_DIR" || exit 1
  rm -rf WEB-INF META-INF 2>/dev/null || true
  echo "✅ Đã xoá các file giải nén (giữ lại $WAR_FILE)"
}

case "$ACTION" in
  start) start_app ;;
  stop) stop_app ;;
  status) status_app ;;
  restart)
    stop_app
    sleep 1
    start_app
    ;;
  deploy) deploy_app ;;
  remove) remove_app ;;
  *)
    echo "Usage: $0 <app_name> {start|stop|status|restart|deploy|remove}"
    exit 1
    ;;
esac
