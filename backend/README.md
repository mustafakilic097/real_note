# Backend (Flask + Firebase Auth)


https://github.com/user-attachments/assets/d9f7fb8e-3071-4c9a-a372-fdc0aae4588b


Firebase ile **kimlik doğrulaması** yapılan bir **Flask** API sunar. Veri katmanı Firestore (Google Cloud) üzerindedir.

## 1) Gereksinimler

* Python 3.10+
* Google Cloud **Service Account** JSON (Firebase projenle **aynı** proje!)
* (İsteğe bağlı) Postman

## 2) Kurulum

### Sanal ortam & bağımlılıklar

**Windows (PowerShell):**

```powershell
cd backend
python -m venv .venv
. .venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### Ortam değişkenleri (.env)

`backend/.env` dosyası oluştur:

```env
# Service account dosyanın tam yolu
GOOGLE_APPLICATION_CREDENTIALS=C:\full\path\to\serviceAccount-real-note.json

# (Opsiyonel) Flask sunucu
HOST=127.0.0.1
PORT=8000

# (Opsiyonel) CORS izinleri (virgül ile ayır)
CORS_ORIGINS=http://127.0.0.1:5500,http://localhost:5500
```

> **Önemli:** Service account’ın `project_id` değeri, Flutter uygulamandaki `firebase_options.dart` içindeki `projectId` ile **aynı** olmalı.

## 3) Çalıştırma

```bash
# aktif sanal ortam içinde
python app.py
# veya
# flask --app app.py run --host=127.0.0.1 --port=8000
```

* Base URL (yerel): `http://127.0.0.1:8000`
* Android emülatöründen erişim: `http://10.0.2.2:8000`

## 4) Dosya Yapısı (özet)

* **app.py** → Flask uygulaması; `/health`, `/whoami`, `/notes` CRUD
* **auth.py** → Firebase Admin init + `require_auth` decorator (Bearer **ID token** doğrulama)
* **firestore\_db.py** → Firestore erişimi (koleksiyon: `notes`)
* **models.py** → Pydantic şemaları (örn. `NoteIn`) ve DTO yardımcıları
* **requirements.txt** → Python bağımlılıkları
* **.env.example** → Örnek ortam değişkenleri
* **README.md** → Bu dosya

## 5) Kimlik Doğrulama

Tüm **/notes** uçları Firebase **ID Token** ister.

Header:

```
Authorization: Bearer <FIREBASE_ID_TOKEN>
```

Token’ı Flutter’dan örnek:

```dart
final t = await FirebaseAuth.instance.currentUser!.getIdToken(true);
```

## 6) API Referansı

### 6.1 Sağlık

**GET** `/health` → `200 {"status":"ok"}`

### 6.2 Oturum Bilgisi

**GET** `/whoami` *(Auth zorunlu)*
Yanıt: `200 {"uid": "<firebase_uid>"}`

### 6.3 Not Listele

**GET** `/notes` *(Auth zorunlu)*

* Kendi notlarını döner: `[{id, userId, title, content, createdAt, updatedAt}]`

### 6.4 Not Oluştur

**POST** `/notes` *(Auth zorunlu)*
Body:

```json
{ "title": "Başlık", "content": "İçerik" }
```

Yanıt: `201` + oluşturulan not

> İsteğe bağlı olarak `{"id":"<uuid>"}` gönderebilirsin. **Başka kullanıcıya ait mevcut id** ise `403` döner.

### 6.5 Not Güncelle

**PUT** `/notes/{id}` *(Auth zorunlu)*
Body:

```json
{ "title": "Yeni başlık", "content": "Yeni içerik" }
```

Yanıt: `200` + güncel not

* Başka kullanıcıya aitse: `403`
* Yoksa: `404`

### 6.6 Not Sil

**DELETE** `/notes/{id}` *(Auth zorunlu)*
Yanıt: `200 {"ok": true}`

* Başka kullanıcıya aitse: `403`
* Yoksa: `404`

## 7) Hızlı cURL Örnekleri

```bash
# Değişken: ID token
TOKEN="eyJhbGciOi..." 

curl -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8000/whoami

curl -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8000/notes

curl -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"title":"İlk Not","content":"Merhaba"}' \
  http://127.0.0.1:8000/notes
```
