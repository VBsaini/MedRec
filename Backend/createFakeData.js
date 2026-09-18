const mongoose = require("mongoose");
const bcrypt = require("bcrypt");
const User = require("./models/User");
const MedicalHistory = require("./models/MedicalHistory");
const Allergy = require("./models/Allergy");
const Surgery = require("./models/Surgery");
const Medication = require("./models/Medication");
const EmergencyContact = require("./models/EmergencyContact");
const FamilyHistory = require("./models/FamilyHistory");
const Report = require("./models/Report");

require("dotenv").config({
  path: require("path").resolve(__dirname, "../.env"),
});

async function createFakeData() {
  try {
    // Connect to MongoDB
    const uri = "mongodb+srv://test:admin@mrcard.ykvwdr3.mongodb.net/?retryWrites=true&w=majority&appName=MRCard"
;
    console.log("Connecting to MongoDB...");

    await mongoose.connect(uri, {
      serverSelectionTimeoutMS: 30000,
      socketTimeoutMS: 45000,
    });

    console.log("✅ Connected to MongoDB successfully!");

    // Clear existing data
    console.log("🗑️  Clearing existing data...");
    await Promise.all([
      User.deleteMany({}),
      MedicalHistory.deleteMany({}),
      Allergy.deleteMany({}),
      Surgery.deleteMany({}),
      Medication.deleteMany({}),
      EmergencyContact.deleteMany({}),
      FamilyHistory.deleteMany({}),
      Report.deleteMany({}),
    ]);

    console.log("✅ Cleared existing data");

    // Create Medications first
    console.log("💊 Creating medications...");
    const medications = await Medication.insertMany([
      {
        name: "Metformin",
        dosage: "500mg",
        frequency: "Twice daily",
        prescribedBy: "Dr. Sharma",
        prescribedFor: "Type 2 Diabetes",
        startDate: new Date("2023-01-15"),
      },
      {
        name: "Lisinopril",
        dosage: "10mg",
        frequency: "Once daily",
        prescribedBy: "Dr. Patel",
        prescribedFor: "Hypertension",
        startDate: new Date("2022-06-10"),
      },
      {
        name: "Aspirin",
        dosage: "75mg",
        frequency: "Once daily",
        prescribedBy: "Dr. Kumar",
        prescribedFor: "Heart Disease Prevention",
        startDate: new Date("2023-03-20"),
      },
      {
        name: "Albuterol",
        dosage: "90mcg",
        frequency: "As needed",
        prescribedBy: "Dr. Singh",
        prescribedFor: "Asthma",
        startDate: new Date("2022-11-05"),
      },
      {
        name: "Sertraline",
        dosage: "50mg",
        frequency: "Once daily",
        prescribedBy: "Dr. Gupta",
        prescribedFor: "Depression",
        startDate: new Date("2023-02-01"),
      },
    ]);

    // Create Surgeries
    console.log("🏥 Creating surgeries...");
    const surgeries = await Surgery.insertMany([
      {
        patientName: "Vaibhav Saini",
        hospitalName: "Apollo Hospital Delhi",
        doctorName: "Dr. Rajesh Khanna",
        surgeryType: "Appendectomy",
        surgeryDate: new Date("2022-05-15"),
        details:
          "Emergency laparoscopic appendectomy due to acute appendicitis",
        recordNumber: "APL2022051501",
      },
      {
        patientName: "Aakash Kamal",
        hospitalName: "AIIMS New Delhi",
        doctorName: "Dr. Priya Sharma",
        surgeryType: "Knee Surgery",
        surgeryDate: new Date("2023-01-20"),
        details: "Arthroscopic meniscus repair for sports injury",
        recordNumber: "AII2023012001",
      },
      {
        patientName: "Himanshu Tiwari",
        hospitalName: "Fortis Hospital Gurgaon",
        doctorName: "Dr. Amit Singh",
        surgeryType: "Gallbladder Removal",
        surgeryDate: new Date("2022-09-10"),
        details: "Laparoscopic cholecystectomy for gallstones",
        recordNumber: "FOR2022091001",
      },
    ]);

    // Create Allergies
    console.log("🤧 Creating allergies...");
    const allergies = await Allergy.insertMany([
      {
        allergens: "Peanuts",
        reactions: "Hives, swelling, difficulty breathing",
        severity: "Severe",
      },
      {
        allergens: "Penicillin",
        reactions: "Skin rash, itching",
        severity: "Moderate",
      },
      {
        allergens: "Dust mites",
        reactions: "Sneezing, runny nose, watery eyes",
        severity: "Mild",
      },
      {
        allergens: "Shellfish",
        reactions: "Nausea, vomiting, diarrhea",
        severity: "Moderate",
      },
      {
        allergens: "Latex",
        reactions: "Skin irritation, contact dermatitis",
        severity: "Mild",
      },
      {
        allergens: "Sulfa drugs",
        reactions: "Fever, rash, joint pain",
        severity: "Severe",
      },
    ]);

    // Create Emergency Contacts
    console.log("📞 Creating emergency contacts...");
    const emergencyContacts = await EmergencyContact.insertMany([
      {
        name: "Kavita Saini",
        phone_number: "+91-9876543210",
        relationship: "Mother",
      },
      {
        name: "Rohit Saini",
        phone_number: "+91-9876543211",
        relationship: "Brother",
      },
      {
        name: "Priya Kamal",
        phone_number: "+91-9876543212",
        relationship: "Wife",
      },
      {
        name: "Rajesh Kamal",
        phone_number: "+91-9876543213",
        relationship: "Father",
      },
      {
        name: "Sunita Tiwari",
        phone_number: "+91-9876543214",
        relationship: "Mother",
      },
      {
        name: "Vikash Tiwari",
        phone_number: "+91-9876543215",
        relationship: "Brother",
      },
    ]);

    // Create Family History
    console.log("👨‍👩‍👧‍👦 Creating family history...");
    const familyHistory = await FamilyHistory.insertMany([
      {
        relationship: "Father",
        conditions: "Type 2 Diabetes, Hypertension",
        medications: [medications[0]._id, medications[1]._id],
        surgeries: [],
      },
      {
        relationship: "Mother",
        conditions: "Breast Cancer (survived), High Cholesterol",
        medications: [],
        surgeries: [],
      },
      {
        relationship: "Grandfather (Paternal)",
        conditions: "Heart Disease, Stroke",
        medications: [medications[2]._id],
        surgeries: [],
      },
    ]);

    // Create Medical History
    console.log("📋 Creating medical history...");
    const medicalHistories = await MedicalHistory.insertMany([
      {
        past_illnesses: "Appendicitis (2022), Childhood Asthma",
        surgeries: [surgeries[0]._id],
        medications: [medications[3]._id],
      },
      {
        past_illnesses: "Sports-related knee injury (2023), Seasonal allergies",
        surgeries: [surgeries[1]._id],
        medications: [],
      },
      {
        past_illnesses: "Gallstones (2022), Depression episode (2023)",
        surgeries: [surgeries[2]._id],
        medications: [medications[4]._id],
      },
    ]);

    // Hash passwords
    console.log("🔒 Hashing passwords...");
    const hashedPassword1 = await bcrypt.hash("password123", 10);
    const hashedPassword2 = await bcrypt.hash("secure456", 10);
    const hashedPassword3 = await bcrypt.hash("mypass789", 10);

    // Create Users
    console.log("👥 Creating users...");
    const users = await User.insertMany([
      {
        email: "vaibhav.saini@email.com",
        password: hashedPassword1,
        alias: "vaibhav_s",
        card_Id: "MED001",
        name: "Vaibhav Saini",
        age: 30,
        gender: "Male",
        blood_group: "O+",
        height: 170,
        weight: 68,
        medical_history: [medicalHistories[0]._id],
        allergies: [allergies[0]._id, allergies[1]._id],
        family_history: [familyHistory[0]._id, familyHistory[1]._id],
        diabetic: {
          status: true,
          type: "Type 2",
          since: new Date("2023-01-15"),
        },
        heart: {
          status: false,
          details: null,
          surgeries: [],
          medications: [],
          since: null,
        },
        mental_health: {
          status: true,
          details: "Mild depression following major life changes",
          since: new Date("2023-02-01"),
          medications: [medications[4]._id],
        },
        emergency_contact: [emergencyContacts[0]._id, emergencyContacts[1]._id],
      },
      {
        email: "aakash.kamal@email.com",
        password: hashedPassword2,
        alias: "aakash_k",
        card_Id: "MED002",
        name: "Aakash Kamal",
        age: 28,
        gender: "Male",
        blood_group: "A+",
        height: 175,
        weight: 72,
        medical_history: [medicalHistories[1]._id],
        allergies: [allergies[2]._id, allergies[4]._id],
        family_history: [familyHistory[2]._id],
        diabetic: {
          status: false,
          type: null,
          since: null,
        },
        heart: {
          status: false,
          details: null,
          surgeries: [],
          medications: [],
          since: null,
        },
        mental_health: {
          status: false,
          details: null,
          since: null,
          medications: [],
        },
        emergency_contact: [emergencyContacts[2]._id, emergencyContacts[3]._id],
      },
      {
        email: "himanshu.tiwari@email.com",
        password: hashedPassword3,
        alias: "himanshu_t",
        card_Id: "MED003",
        name: "Himanshu Tiwari",
        age: 25,
        gender: "Male",
        blood_group: "B+",
        height: 180,
        weight: 78,
        medical_history: [medicalHistories[2]._id],
        allergies: [allergies[3]._id, allergies[5]._id],
        family_history: [familyHistory[0]._id],
        diabetic: {
          status: false,
          type: null,
          since: null,
        },
        heart: {
          status: false,
          details: null,
          surgeries: [],
          medications: [],
          since: null,
        },
        mental_health: {
          status: false,
          details: null,
          since: null,
          medications: [],
        },
        emergency_contact: [emergencyContacts[4]._id, emergencyContacts[5]._id],
      },
    ]);

    // Create Reports
    console.log("📄 Creating reports...");
    await Report.insertMany([
      {
        user: users[0]._id,
        title: "Annual Health Checkup 2024",
        description: "Complete blood work and physical examination results",
        summary:
          "Overall health is good. Diabetes well controlled. Continue current medication regimen.",
        date: new Date("2024-03-15"),
      },
      {
        user: users[0]._id,
        title: "Post-Surgery Follow-up",
        description: "Follow-up examination after appendectomy",
        summary:
          "Surgical site healing well. No complications observed. Cleared for normal activities.",
        date: new Date("2022-06-15"),
      },
      {
        user: users[1]._id,
        title: "Sports Medicine Consultation",
        description: "Consultation regarding knee injury and treatment options",
        summary:
          "Knee injury requires surgical intervention. Arthroscopic surgery scheduled.",
        date: new Date("2022-12-20"),
      },
      {
        user: users[1]._id,
        title: "Post-Surgical Recovery Assessment",
        description: "Post-operative assessment following knee surgery",
        summary:
          "Recovery progressing well. Physical therapy recommended for optimal healing.",
        date: new Date("2023-03-01"),
      },
      {
        user: users[2]._id,
        title: "Mental Health Assessment",
        description: "Psychological evaluation and treatment plan",
        summary:
          "Mild to moderate depression. Responding well to medication and therapy.",
        date: new Date("2023-04-15"),
      },
      {
        user: users[2]._id,
        title: "Gallbladder Surgery Follow-up",
        description: "Post-operative follow-up after gallbladder removal",
        summary:
          "Surgery successful. Patient recovering well. No post-operative complications.",
        date: new Date("2022-10-15"),
      },
    ]);

    console.log("\n🎉 ✅ Fake data created successfully!");
    console.log("\n📊 Data Summary:");
    console.log(`👥 Users: ${users.length}`);
    console.log(`💊 Medications: ${medications.length}`);
    console.log(`🏥 Surgeries: ${surgeries.length}`);
    console.log(`🤧 Allergies: ${allergies.length}`);
    console.log(`📞 Emergency Contacts: ${emergencyContacts.length}`);
    console.log(`👨‍👩‍👧‍👦 Family History Records: ${familyHistory.length}`);
    console.log(`📋 Medical History Records: ${medicalHistories.length}`);
    console.log(`📄 Reports: 6`);

    console.log("\n👤 Created Users:");
    users.forEach((user, index) => {
      console.log(`${index + 1}. ${user.name} (${user.alias}) - ${user.email}`);
    });

    console.log("\n🔐 Login Credentials:");
    console.log("1. Email: vaibhav.saini@email.com, Password: password123");
    console.log("2. Email: aakash.kamal@email.com, Password: secure456");
    console.log("3. Email: himanshu.tiwari@email.com, Password: mypass789");
  } catch (error) {
    console.error("❌ Error creating fake data:", error);
  } finally {
    mongoose.connection.close();
    console.log("\n🔌 Database connection closed");
  }
}

createFakeData();
