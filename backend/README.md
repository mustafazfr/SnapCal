# CalorieLens — Backend Proxy (Cloudflare Workers)

API key'i client-side'dan gizlemek için kullanılan basit bir proxy.

## Kurulum

### 1. Wrangler CLI'ı yükle

```bash
npm install -g wrangler
wrangler login
```

### 2. Bağımlılıkları yükle

```bash
cd backend
npm install
```

### 3. Secret'ları ayarla

```bash
# Anthropic API key (asla .env'e koyma)
wrangler secret put ANTHROPIC_API_KEY

# Flutter app'ın worker'a göndereceği paylaşımlı secret
wrangler secret put APP_SECRET
```

### 4. Deploy et

```bash
npm run deploy
```

Deploy URL'ini not al: `https://calorielens-api.<your-subdomain>.workers.dev`

---

## Flutter tarafında aktivasyon

`.env` dosyasına ekle:

```
BACKEND_URL=https://calorielens-api.<your-subdomain>.workers.dev
APP_SECRET=<aynı secret>
```

`BACKEND_URL` set edildiğinde `claude_service.dart` otomatik olarak proxy'yi kullanır.
Set edilmediğinde direkt Anthropic API'ye bağlanır (geliştirme modu).

---

## Endpoints

| Method | Path | Açıklama |
|--------|------|----------|
| POST | `/api/analyze` | Yemek fotoğrafı analizi (Claude Sonnet) |
| POST | `/api/chat` | Sağlık chatbox (Claude Haiku) |
| POST | `/api/report` | Haftalık beslenme raporu (Claude Haiku) |

Tüm isteklerde `x-app-secret` header'ı gereklidir.

---

## Geliştirme ortamı

```bash
npm run dev   # Local'de çalıştır (localhost:8787)
```
