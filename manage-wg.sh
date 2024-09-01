#!/bin/bash

WG_CONFIG="/etc/wireguard/wg1.conf"
SERVER_PRIV_KEY_FILE="/etc/wireguard/server.priv"
SERVER_PUBLIC_KEY=$(wg pubkey < "$SERVER_PRIV_KEY_FILE")
SERVER_ENDPOINT="example.com:62011"
CLIENT_IP_PREFIX="10.66.66."
CLIENT_IPv6_PREFIX="fd42:42:42::"
CLIENT_IP_RANGE_START=200
CLIENT_IP_RANGE_END=254
CLIENT_IPv6_RANGE_START=20  # Начальное значение для диапазона IPv6
CLIENT_IPv6_RANGE_END=254

function add_client() {
  CLIENT_NAME="$1"
  CLIENT_DIR="/etc/wireguard/clients/$CLIENT_NAME"

  # Проверка существующих IP-адресов IPv4 в конфигурационном файле
  LAST_IP=$(grep -oP "AllowedIPs\s*=\s*10\.66\.66\.\K[0-9]+" "$WG_CONFIG" | sort -n | tail -n 1)

  if [ -z "$LAST_IP" ]; then
    NEXT_IP=$CLIENT_IP_RANGE_START
  else
    if [ "$LAST_IP" -ge "$CLIENT_IP_RANGE_END" ]; then
      echo "Нет доступных IPv4-адресов в диапазоне 10.66.66.200-254"
      exit 1
    fi
    NEXT_IP=$((LAST_IP + 1))
  fi

  # Проверка существующих IP-адресов IPv6 в конфигурационном файле
  LAST_IPv6=$(grep -oP "fd42:42:42::\K[0-9a-f]+(?=/128)" "$WG_CONFIG" | sort -n | tail -n 1)

  # Логика назначения следующего IPv6-адреса
  if [ -z "$LAST_IPv6" ]; then
    NEXT_IPv6=$CLIENT_IPv6_RANGE_START
  else
    LAST_IPv6_DECIMAL=$((16#$LAST_IPv6))  # Преобразование последнего IPv6 суффикса из шестнадцатеричного в десятичный
    if [ "$LAST_IPv6_DECIMAL" -ge "$CLIENT_IPv6_RANGE_END" ]; then
      echo "Нет доступных IPv6-адресов в диапазоне fd42:42:42::20-254"
      exit 1
    fi
    NEXT_IPv6=$((LAST_IPv6_DECIMAL + 1))
  fi

  CLIENT_IP="${CLIENT_IP_PREFIX}${NEXT_IP}/32"
  CLIENT_IPv6="${CLIENT_IPv6_PREFIX}$(printf '%x' $NEXT_IPv6)/128"

  # Создание директории для клиента
  mkdir -p "$CLIENT_DIR"

  # Генерация ключей клиента
  CLIENT_PRIVATE_KEY=$(wg genkey)
  CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)
  CLIENT_PRIVATE_KEY_FILE="$CLIENT_DIR/private"
  CLIENT_PUBLIC_KEY_FILE="$CLIENT_DIR/public"

  # Генерация предварительно разделенного ключа (PSK)
  PSK=$(wg genpsk)
  PSK_FILE="$CLIENT_DIR/psk"

  # Сохранение ключей в файлы
  echo "$CLIENT_PRIVATE_KEY" > "$CLIENT_PRIVATE_KEY_FILE"
  echo "$CLIENT_PUBLIC_KEY" > "$CLIENT_PUBLIC_KEY_FILE"
  echo "$PSK" > "$PSK_FILE"

  # Добавление клиента в конфигурацию сервера с меткой
  echo -e "\n# peer_$CLIENT_NAME\n[Peer]
PublicKey = $(cat "$CLIENT_PUBLIC_KEY_FILE")
PresharedKey = $(cat "$PSK_FILE")
AllowedIPs = $CLIENT_IP, $CLIENT_IPv6" | sudo tee -a "$WG_CONFIG" > /dev/null

  # Создание клиентского конфигурационного файла
  CLIENT_CONFIG="$CLIENT_DIR/$CLIENT_NAME.conf"
  echo "[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP, $CLIENT_IPv6
DNS = 8.8.8.8, 1.1.1.1, 2001:4860:4860::8888
ListenPort = 51820

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
PresharedKey = $PSK
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $SERVER_ENDPOINT" > "$CLIENT_CONFIG"

  # Вывод информации
  echo "Клиентская конфигурация для $CLIENT_NAME создана:"
  cat "$CLIENT_CONFIG"

  echo "Ключи клиента сохранены в $CLIENT_DIR."
  echo "Клиент добавлен в конфигурацию сервера $WG_CONFIG."

  # Обновление конфигурации WireGuard без перерыва соединений
  TEMP_CONFIG="/etc/wireguard/wg1_temp.conf"
  wg-quick strip wg1 > "$TEMP_CONFIG"
  sudo wg setconf wg1 "$TEMP_CONFIG"
  rm "$TEMP_CONFIG"
  echo "Конфигурация wg1 успешно обновлена."

  # Печать QR-кода в терминале
  echo "QR-код для клиента $CLIENT_NAME:"
  qrencode -t ansiutf8 < "$CLIENT_CONFIG"

  # Предлагаем сохранить QR-код в файл
  read -p "Хотите сохранить QR-код в файл? (y/n): " generate_qr
  if [ "$generate_qr" == "y" ]; then
    qrencode -o "$CLIENT_DIR/$CLIENT_NAME.png" < "$CLIENT_CONFIG"
    echo "QR-код сохранен в $CLIENT_DIR/$CLIENT_NAME.png"
  fi
}

function delete_client() {
  CLIENT_NAME="$1"
  CLIENT_DIR="/etc/wireguard/clients/$CLIENT_NAME"

  # Удаление записи клиента из конфигурационного файла wg1.conf
  sudo sed -i "/# peer_$CLIENT_NAME/,/AllowedIPs/d" "$WG_CONFIG"

  # Удаление клиентских файлов
  if [ -d "$CLIENT_DIR" ]; then
    rm -rf "$CLIENT_DIR"
    echo "Данные клиента $CLIENT_NAME удалены."
  else
    echo "Клиент $CLIENT_NAME не найден."
  fi

  # Обновление конфигурации WireGuard без перерыва соединений
  TEMP_CONFIG="/etc/wireguard/wg1_temp.conf"
  wg-quick strip wg1 > "$TEMP_CONFIG"
  sudo wg setconf wg1 "$TEMP_CONFIG"
  rm "$TEMP_CONFIG"
  echo "Конфигурация wg1 успешно обновлена."
}

# Главная функция
if [ "$2" == "add" ]; then
  add_client "$1"
elif [ "$2" == "delete" ]; then
  delete_client "$1"
else
  echo "Usage: $0 <client_name> <add|delete>"
fi

