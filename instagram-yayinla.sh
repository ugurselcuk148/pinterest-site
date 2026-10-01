#!/data/data/com.termux/files/usr/bin/bash

set -u

API="https://graph.facebook.com/v26.0"
IG_ID="17841423067493607"
REPO_RAW="https://raw.githubusercontent.com/Ugurselcuk148/pinterest-site/main"
TOKEN_FILE=".instagram_page_token"

IMAGE="${1:-}"
CAPTION="${2:-}"

if [ -z "$IMAGE" ]; then
  echo 'Kullanim: ./instagram-yayinla.sh dosya.png "Açıklama"'
  exit 1
fi

if [ ! -f "$IMAGE" ]; then
  echo "HATA: Dosya bulunamadi: $IMAGE"
  exit 1
fi

if [ ! -s "$TOKEN_FILE" ]; then
  echo "HATA: Page Access Token bulunamadi."
  exit 1
fi

TOKEN="$(cat "$TOKEN_FILE")"
FILENAME="$(basename "$IMAGE")"
IMAGE_URL="$REPO_RAW/$FILENAME"

echo "1/4 Instagram medya container olusturuluyor..."

if [ -n "$CAPTION" ]; then
  RESPONSE="$(curl -sS -X POST \
    "$API/$IG_ID/media" \
    --data-urlencode "image_url=$IMAGE_URL" \
    --data-urlencode "caption=$CAPTION" \
    --data-urlencode "access_token=$TOKEN")"
else
  RESPONSE="$(curl -sS -X POST \
    "$API/$IG_ID/media" \
    --data-urlencode "image_url=$IMAGE_URL" \
    --data-urlencode "access_token=$TOKEN")"
fi

if printf '%s' "$RESPONSE" | grep -q '"error"'; then
  echo "HATA: Container olusturulamadi."
  echo "$RESPONSE"
  exit 1
fi

CONTAINER_ID="$(printf '%s' "$RESPONSE" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')"

if [ -z "$CONTAINER_ID" ]; then
  echo "HATA: Container ID alinamadi."
  echo "$RESPONSE"
  exit 1
fi

echo "Container ID: $CONTAINER_ID"
echo "2/4 Instagram görseli hazirliyor..."

READY=0

for i in $(seq 1 24); do
  STATUS="$(curl -sS -G \
    "$API/$CONTAINER_ID" \
    --data-urlencode "fields=status_code,status" \
    --data-urlencode "access_token=$TOKEN")"

  echo "Durum: $STATUS"

  if printf '%s' "$STATUS" | grep -q '"status_code":"FINISHED"'; then
    READY=1
    break
  fi

  if printf '%s' "$STATUS" | grep -q '"status_code":"ERROR"'; then
    echo "HATA: Instagram medya container hatasi."
    exit 1
  fi

  if printf '%s' "$STATUS" | grep -q '"error"'; then
    echo "HATA: Container durum sorgusu basarisiz."
    exit 1
  fi

  sleep 5
done

if [ "$READY" -ne 1 ]; then
  echo "HATA: Container zamaninda hazir olmadi."
  exit 1
fi

echo "3/4 Instagram'da yayinlaniyor..."

PUBLISH_RESPONSE="$(curl -sS -X POST \
  "$API/$IG_ID/media_publish" \
  --data-urlencode "creation_id=$CONTAINER_ID" \
  --data-urlencode "access_token=$TOKEN")"

if printf '%s' "$PUBLISH_RESPONSE" | grep -q '"error"'; then
  echo "HATA: Instagram yayinlama basarisiz."
  echo "$PUBLISH_RESPONSE"
  exit 1
fi

MEDIA_ID="$(printf '%s' "$PUBLISH_RESPONSE" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')"

if [ -z "$MEDIA_ID" ]; then
  echo "HATA: Instagram Media ID alinamadi."
  echo "$PUBLISH_RESPONSE"
  exit 1
fi

echo "4/4 BASARILI! 🎉"
echo "Instagram Media ID: $MEDIA_ID"
echo "Gorsel: $IMAGE_URL"
