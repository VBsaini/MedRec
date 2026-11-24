# MedRec Backend: Data Model and API

## Data model

### User (the patient)

- `email`, `alias`: unique, required. `password`: bcrypt hash, never returned by the API.
- `card_Id`: UID of the linked RFID card (unique, optional).
- `name`, `age`, `gender`, `blood_group`, `height` (cm), `weight` (kg).
- `diabetic`: `{ status, type, since }`
- `heart`: `{ status, details, since }`
- `mental_health`: `{ status, details, since }`
- Lists of references: `allergies`, `medications`, `surgeries`, `medical_history`, `family_history`, `emergency_contact`.

Older records stored surgeries and medications under `heart.surgeries`, `heart.medications` and `mental_health.medications`. Those fields still exist and are still returned, but new entries go in the top-level `surgeries` and `medications` lists.

### Record entries

| Model | Fields (required in bold) |
|---|---|
| Allergy | **allergens**, **reactions**, **severity** |
| Medication | **name**, dosage, frequency, prescribedBy, prescribedFor, startDate, endDate |
| Surgery | **surgeryType**, **surgeryDate**, hospitalName, doctorName, details (`recordNumber` and `patientName` are filled in by the server) |
| MedicalHistory | **past_illnesses** |
| FamilyHistory | **relationship**, **conditions** |
| EmergencyContact | **name**, **phone_number**, relationship |

### Report

- `user`, **`title`**, `description`, `date`
- `category`: `lab_report`, `prescription`, `scan`, `discharge_summary` or `other`
- `files`: `[{ _id, originalName, mimeType, size }]`

Uploaded files are saved under `uploads/reports/` with random names. They are not served statically; the only way to read one is the authenticated download route below.

### Visitor

A log entry created when someone views a record by card: `name`, `purpose`, `card_Id`, `ip_address`, `visitDate`, `user`.

## API

Routes marked **login** need an `Authorization: Bearer <token>` header and only ever act on the logged-in patient's own data. Errors are returned as `{ "message": "..." }`.

### Auth

| Method | Endpoint | Access | Description |
|---|---|---|---|
| POST | `/api/auth/signup` | public | Body `{ name, alias, email, password }`. Returns `{ token, user }`. |
| POST | `/api/auth/login` | public | Body `{ email, password }`. Returns `{ token, user }`. |
| GET | `/api/auth/me` | login | The logged-in patient's full record. |

### My record

| Method | Endpoint | Access | Description |
|---|---|---|---|
| GET | `/api/me` | login | Full record with every list populated. |
| PATCH | `/api/me/profile` | login | Update basic details and the `diabetic` / `heart` / `mental_health` sections. Unknown fields are ignored; `""` clears a field. |
| PUT | `/api/me/card` | login | Body `{ card_Id }`. Links a card; an empty value unlinks it. |
| GET | `/api/me/visitors` | login | Who has viewed the record by card. |
| GET | `/api/me/:list` | login | Entries of one list. |
| POST | `/api/me/:list` | login | Add an entry. |
| PUT | `/api/me/:list/:id` | login | Edit an entry. |
| DELETE | `/api/me/:list/:id` | login | Delete an entry. |

`:list` is one of `allergies`, `medications`, `surgeries`, `medical-history`, `family-history`, `emergency-contacts`.

### Reports and files

Uploads are `multipart/form-data` with the files in a field named `files`. Allowed types are JPG, PNG, WEBP, HEIC and PDF, up to 10 files per report and 10 MB per file (`MAX_UPLOAD_MB`).

| Method | Endpoint | Access | Description |
|---|---|---|---|
| POST | `/api/reports` | login | Create a report. Fields: `title`, `category`, `date`, `description`, `files`. |
| GET | `/api/reports` | login | My reports, newest first. |
| GET | `/api/reports/:id` | login | One report. |
| PATCH | `/api/reports/:id` | login | Edit title, category, date or description. |
| DELETE | `/api/reports/:id` | login | Delete a report and its files. |
| POST | `/api/reports/:id/files` | login | Add files to a report. |
| GET | `/api/reports/:id/files/:fileId` | login | Download a file. |
| DELETE | `/api/reports/:id/files/:fileId` | login | Delete one file. |

### Card access (no login)

| Method | Endpoint | Access | Description |
|---|---|---|---|
| GET | `/api/records/user/card/:cardId` | public | The record shown when a card is scanned. Excludes email, password and reports. |
| POST | `/api/records/visitor` | public | Body `{ name, purpose, card_Id }`. Logs a visit. |
| GET | `/api/health` | public | Health check. |
