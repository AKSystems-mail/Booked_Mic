const admin = require('firebase-admin');

// Initialize with your project ID
admin.initializeApp({
  projectId: 'bookedmic-1cf9d'
});

const db = admin.firestore();

async function bulkGenerateHostCodes() {
  console.log("Starting bulk host code generation...");
  
  const usersSnapshot = await db.collection('users').get();
  const existingCodes = new Set();

  // 1. Collect existing codes to ensure uniqueness
  usersSnapshot.forEach(doc => {
    const data = doc.data();
    if (data.hostCode) {
      existingCodes.add(data.hostCode);
    }
  });

  let updatedCount = 0;
  const batch = db.batch();

  // 2. Loop through users and assign codes
  for (const userDoc of usersSnapshot.docs) {
    const userData = userDoc.data();
    
    if (!userData.hostCode || userData.hostCode === "" || userData.hostCode === "......") {
      let uniqueCode = "";
      let isUnique = false;

      while (!isUnique) {
        uniqueCode = (Math.floor(Math.random() * 900000) + 100000).toString();
        if (!existingCodes.has(uniqueCode)) {
          isUnique = true;
          existingCodes.add(uniqueCode);
        }
      }

      batch.update(userDoc.ref, { 
        hostCode: uniqueCode,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`Generated code ${uniqueCode} for user ${userDoc.id} (${userData.email || 'No Email'})`);
      updatedCount++;
    }
  }

  // 3. Commit changes
  if (updatedCount > 0) {
    await batch.commit();
    console.log(`Successfully assigned host codes to ${updatedCount} users.`);
  } else {
    console.log("No users needed a host code update.");
  }
}

bulkGenerateHostCodes().catch(console.error);
