# MedRec Backend Database & API Routes Documentation

## Database Schema Overview

### User

- `Id`: String, unique
- `card_Id`: String, unique
- `name`, `age`, `gender`, `blood_group`, `height`, `weight`: Basic info
- `medical_history`: Array of ObjectIds (MedicalHistory)
- `allergies`: Array of ObjectIds (Allergy)
- `family_history`: Array of ObjectIds (FamilyHistory)
- `diabetic`: { status, type, since }
- `heart`: { status, details, surgeries (array of Surgery), medications (array of Medication), since }
- `mental_health`: { status, details, since, medications (array of Medication) }
- `emergency_contact`: Array of ObjectIds (EmergencyContact)
- `createdAt`: Date

### MedicalHistory

- `past_illnesses`: String
- `surgeries`: Array of ObjectIds (Surgery)
- `medications`: Array of ObjectIds (Medication)

### Allergy

- `allergens`, `reactions`, `severity`: String

### FamilyHistory

- `relationship`, `conditions`: String
- `medications`: Array of ObjectIds (Medication)
- `surgeries`: Array of ObjectIds (Surgery)

### EmergencyContact

- `name`, `phone_number`, `relationship`: String

### Surgery

- `patientName`, `hospitalName`, `doctorName`, `surgeryType`, `surgeryDate`, `details`, `recordNumber`, `createdAt`

### Medication

- `name`, `dosage`, `frequency`, `prescribedBy`, `prescribedFor`, `startDate`, `endDate`

---

## API Routes

### Auth

- `POST /api/auth/signup` — Register user (email, password required)
- `POST /api/auth/login` — Login (returns JWT token)

### User Profile

- `POST /api/records/user/:id/profile` — Update user profile fields

### Medical History

- `POST /api/records/medical-history/:userId` — Add medical history to user

### Allergy

- `POST /api/records/allergy/:userId` — Add allergy to user

### Family History

- `POST /api/records/family-history/:userId` — Add family history to user

### Emergency Contact

- `POST /api/records/emergency-contact/:userId` — Add emergency contact to user

### Surgery

- `POST /api/records/surgery/:userId` — Add surgery to user's heart.surgeries

### Medication

- `POST /api/records/medication/:userId` — Add medication to user's heart and mental_health

---

## Notes

- All POST endpoints expect JSON bodies.
- All `:userId` params should be the MongoDB ObjectId of the user.
- Passwords are hashed with bcryptjs. Auth uses JWT.
- You can extend the API with GET, PUT, DELETE as needed for your app.

---

For more details, see the code in `/models` and `/routes` folders.
